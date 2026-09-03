use std::collections::BTreeMap;
use std::collections::VecDeque;
use std::fs;
use std::io::Write;
use std::io::{self};
use std::path::PathBuf;
use std::sync::Arc;
use std::sync::Mutex;

use anyhow::Result;
use opencli_protocol::ThreadId;
use tracing::Event;
use tracing::Level;
use tracing::field::Visit;
use tracing_subscriber::Layer;
use tracing_subscriber::filter::Targets;
use tracing_subscriber::fmt::writer::MakeWriter;
use tracing_subscriber::registry::LookupSpan;

const DEFAULT_MAX_BYTES: usize = 4 * 1024 * 1024; // 4 MiB
const FEEDBACK_TAGS_TARGET: &str = "feedback_tags";
const MAX_FEEDBACK_TAGS: usize = 64;

#[derive(Clone)]
pub struct OpenCLIFeedback {
    inner: Arc<FeedbackInner>,
}

impl Default for OpenCLIFeedback {
    fn default() -> Self {
        Self::new()
    }
}

impl OpenCLIFeedback {
    pub fn new() -> Self {
        Self::with_capacity(DEFAULT_MAX_BYTES)
    }

    pub(crate) fn with_capacity(max_bytes: usize) -> Self {
        Self {
            inner: Arc::new(FeedbackInner::new(max_bytes)),
        }
    }

    pub fn make_writer(&self) -> FeedbackMakeWriter {
        FeedbackMakeWriter {
            inner: self.inner.clone(),
        }
    }

    /// Returns a [`tracing_subscriber`] layer that captures full-fidelity logs into this feedback
    /// ring buffer.
    ///
    /// This is intended for initialization code so call sites don't have to duplicate the exact
    /// `fmt::layer()` configuration and filter logic.
    pub fn logger_layer<S>(&self) -> impl Layer<S> + Send + Sync + 'static
    where
        S: tracing::Subscriber + for<'a> LookupSpan<'a>,
    {
        tracing_subscriber::fmt::layer()
            .with_writer(self.make_writer())
            .with_ansi(false)
            .with_target(false)
            // Capture everything, regardless of the caller's `RUST_LOG`, so feedback includes the
            // full trace when the user uploads a report.
            .with_filter(Targets::new().with_default(Level::TRACE))
    }

    /// Returns a [`tracing_subscriber`] layer that collects structured metadata for feedback.
    ///
    /// Events with `target: "feedback_tags"` are treated as key/value tags to attach to feedback
    /// uploads later.
    pub fn metadata_layer<S>(&self) -> impl Layer<S> + Send + Sync + 'static
    where
        S: tracing::Subscriber + for<'a> LookupSpan<'a>,
    {
        FeedbackMetadataLayer {
            inner: self.inner.clone(),
        }
        .with_filter(Targets::new().with_target(FEEDBACK_TAGS_TARGET, Level::TRACE))
    }

    pub fn snapshot(&self, session_id: Option<ThreadId>) -> OpenCLILogSnapshot {
        let bytes = {
            let guard = self.inner.ring.lock().expect("mutex poisoned");
            guard.snapshot_bytes()
        };
        let tags = {
            let guard = self.inner.tags.lock().expect("mutex poisoned");
            guard.clone()
        };
        OpenCLILogSnapshot {
            bytes,
            tags,
            thread_id: session_id
                .map(|id| id.to_string())
                .unwrap_or("no-active-thread-".to_string() + &ThreadId::new().to_string()),
        }
    }
}

struct FeedbackInner {
    ring: Mutex<RingBuffer>,
    tags: Mutex<BTreeMap<String, String>>,
}

impl FeedbackInner {
    fn new(max_bytes: usize) -> Self {
        Self {
            ring: Mutex::new(RingBuffer::new(max_bytes)),
            tags: Mutex::new(BTreeMap::new()),
        }
    }
}

#[derive(Clone)]
pub struct FeedbackMakeWriter {
    inner: Arc<FeedbackInner>,
}

impl<'a> MakeWriter<'a> for FeedbackMakeWriter {
    type Writer = FeedbackWriter;

    fn make_writer(&'a self) -> Self::Writer {
        FeedbackWriter {
            inner: self.inner.clone(),
        }
    }
}

pub struct FeedbackWriter {
    inner: Arc<FeedbackInner>,
}

impl Write for FeedbackWriter {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        let mut guard = self.inner.ring.lock().map_err(|_| io::ErrorKind::Other)?;
        guard.push_bytes(buf);
        Ok(buf.len())
    }

    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}

struct RingBuffer {
    max: usize,
    buf: VecDeque<u8>,
}

impl RingBuffer {
    fn new(capacity: usize) -> Self {
        Self {
            max: capacity,
            buf: VecDeque::with_capacity(capacity),
        }
    }

    fn len(&self) -> usize {
        self.buf.len()
    }

    fn push_bytes(&mut self, data: &[u8]) {
        if data.is_empty() {
            return;
        }

        // If the incoming chunk is larger than capacity, keep only the trailing bytes.
        if data.len() >= self.max {
            self.buf.clear();
            let start = data.len() - self.max;
            self.buf.extend(data[start..].iter().copied());
            return;
        }

        // Evict from the front if we would exceed capacity.
        let needed = self.len() + data.len();
        if needed > self.max {
            let to_drop = needed - self.max;
            for _ in 0..to_drop {
                let _ = self.buf.pop_front();
            }
        }

        self.buf.extend(data.iter().copied());
    }

    fn snapshot_bytes(&self) -> Vec<u8> {
        self.buf.iter().copied().collect()
    }
}

pub struct OpenCLILogSnapshot {
    bytes: Vec<u8>,
    tags: BTreeMap<String, String>,
    pub thread_id: String,
}

impl OpenCLILogSnapshot {
    pub(crate) fn as_bytes(&self) -> &[u8] {
        &self.bytes
    }

    pub fn save_to_temp_file(&self) -> io::Result<PathBuf> {
        let dir = std::env::temp_dir();
        let filename = format!("opencli-feedback-{}.log", self.thread_id);
        let path = dir.join(filename);
        fs::write(&path, self.as_bytes())?;
        Ok(path)
    }

    /// Write a report of this session to a file, for the user to attach.
    ///
    /// This used to post the logs, the whole rollout and a set of tags to a
    /// Sentry project — one belonging to the project this was forked from, so
    /// anyone reporting a problem here was sending their transcript to a third
    /// party who had not asked for it and could not act on it.
    ///
    /// Nothing is uploaded now. The report is a file on this machine, and what
    /// happens to it is the reporter's decision: they can read it, redact it,
    /// and attach it to an issue, or not. That is the same bargain the rest of
    /// this program makes — it talks to what you configured, and nothing else.
    pub fn write_report(
        &self,
        classification: &str,
        reason: Option<&str>,
        include_logs: bool,
        rollout_path: Option<&std::path::Path>,
    ) -> Result<PathBuf> {
        let mut report = String::new();
        report.push_str(&format!(
            "OpenCLI feedback: {}\n",
            display_classification(classification)
        ));
        report.push_str(&format!("Version: {}\n", env!("CARGO_PKG_VERSION")));
        report.push_str(&format!("Thread: {}\n", self.thread_id));
        for (key, value) in &self.tags {
            report.push_str(&format!("{key}: {value}\n"));
        }
        if let Some(reason) = reason {
            report.push_str(&format!("\nWhat happened\n-------------\n{reason}\n"));
        }

        if include_logs {
            report.push_str("\nLogs\n----\n");
            report.push_str(&String::from_utf8_lossy(&self.bytes));

            // The transcript is the most revealing thing here — it is the
            // conversation, including whatever was pasted into it. Included
            // only when logs were asked for, and named in the report so nobody
            // attaches it without knowing it is there.
            if let Some(path) = rollout_path {
                report.push_str(&format!("\nTranscript ({})\n", path.display()));
                report.push_str("----------\n");
                match fs::read_to_string(path) {
                    Ok(transcript) => report.push_str(&transcript),
                    Err(err) => report.push_str(&format!("could not be read: {err}\n")),
                }
            }
        }

        let path = std::env::temp_dir().join(format!("opencli-feedback-{}.txt", self.thread_id));
        fs::write(&path, report)?;
        Ok(path)
    }
}

fn display_classification(classification: &str) -> String {
    match classification {
        "bug" => "Bug".to_string(),
        "bad_result" => "Bad result".to_string(),
        "good_result" => "Good result".to_string(),
        _ => "Other".to_string(),
    }
}

#[derive(Clone)]
struct FeedbackMetadataLayer {
    inner: Arc<FeedbackInner>,
}

impl<S> Layer<S> for FeedbackMetadataLayer
where
    S: tracing::Subscriber + for<'a> LookupSpan<'a>,
{
    fn on_event(&self, event: &Event<'_>, _ctx: tracing_subscriber::layer::Context<'_, S>) {
        // This layer is filtered by `Targets`, but keep the guard anyway in case it is used without
        // the filter.
        if event.metadata().target() != FEEDBACK_TAGS_TARGET {
            return;
        }

        let mut visitor = FeedbackTagsVisitor::default();
        event.record(&mut visitor);
        if visitor.tags.is_empty() {
            return;
        }

        let mut guard = self.inner.tags.lock().expect("mutex poisoned");
        for (key, value) in visitor.tags {
            if guard.len() >= MAX_FEEDBACK_TAGS && !guard.contains_key(&key) {
                continue;
            }
            guard.insert(key, value);
        }
    }
}

#[derive(Default)]
struct FeedbackTagsVisitor {
    tags: BTreeMap<String, String>,
}

impl Visit for FeedbackTagsVisitor {
    fn record_i64(&mut self, field: &tracing::field::Field, value: i64) {
        self.tags
            .insert(field.name().to_string(), value.to_string());
    }

    fn record_u64(&mut self, field: &tracing::field::Field, value: u64) {
        self.tags
            .insert(field.name().to_string(), value.to_string());
    }

    fn record_bool(&mut self, field: &tracing::field::Field, value: bool) {
        self.tags
            .insert(field.name().to_string(), value.to_string());
    }

    fn record_f64(&mut self, field: &tracing::field::Field, value: f64) {
        self.tags
            .insert(field.name().to_string(), value.to_string());
    }

    fn record_str(&mut self, field: &tracing::field::Field, value: &str) {
        self.tags
            .insert(field.name().to_string(), value.to_string());
    }

    fn record_debug(&mut self, field: &tracing::field::Field, value: &dyn std::fmt::Debug) {
        self.tags
            .insert(field.name().to_string(), format!("{value:?}"));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tracing_subscriber::layer::SubscriberExt;
    use tracing_subscriber::util::SubscriberInitExt;

    #[test]
    fn ring_buffer_drops_front_when_full() {
        let fb = OpenCLIFeedback::with_capacity(8);
        {
            let mut w = fb.make_writer().make_writer();
            w.write_all(b"abcdefgh").unwrap();
            w.write_all(b"ij").unwrap();
        }
        let snap = fb.snapshot(None);
        // Capacity 8: after writing 10 bytes, we should keep the last 8.
        pretty_assertions::assert_eq!(std::str::from_utf8(snap.as_bytes()).unwrap(), "cdefghij");
    }

    #[test]
    fn metadata_layer_records_tags_from_feedback_target() {
        let fb = OpenCLIFeedback::new();
        let _guard = tracing_subscriber::registry()
            .with(fb.metadata_layer())
            .set_default();

        tracing::info!(target: FEEDBACK_TAGS_TARGET, model = "gpt-5", cached = true, "tags");

        let snap = fb.snapshot(None);
        pretty_assertions::assert_eq!(snap.tags.get("model").map(String::as_str), Some("gpt-5"));
        pretty_assertions::assert_eq!(snap.tags.get("cached").map(String::as_str), Some("true"));
    }
}
