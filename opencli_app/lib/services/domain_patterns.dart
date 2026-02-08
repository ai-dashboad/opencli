import 'intent_recognizer.dart';

/// All domain intent patterns for Flutter-side quick-path matching.
/// These mirror the daemon's DomainRegistry patterns so the Flutter
/// IntentRecognizer can match locally without round-tripping to the daemon.
List<DomainIntentPatternLocal> buildDomainPatterns() {
  return [
    // ─── Timer ─────────────────────────────────────────────
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:set\s+)?(?:a\s+)?timer\s+(?:for\s+)?(\d+)\s*(min(?:ute)?s?|sec(?:ond)?s?|hour?s?)(?:\s+(.+))?$', caseSensitive: false),
      taskType: 'timer_set',
      extractData: (m) {
        final amount = int.parse(m.group(1)!);
        final unit = m.group(2)!.toLowerCase();
        int minutes = amount;
        if (unit.startsWith('sec')) minutes = (amount / 60).ceil();
        if (unit.startsWith('hour') || unit.startsWith('hr')) minutes = amount * 60;
        return {'minutes': minutes, 'label': m.group(3) ?? 'Timer'};
      },
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(\d+)\s*(?:min(?:ute)?s?)\s+timer$', caseSensitive: false),
      taskType: 'timer_set',
      extractData: (m) => {'minutes': int.parse(m.group(1)!), 'label': 'Timer'},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:start\s+)?pomodoro$', caseSensitive: false),
      taskType: 'timer_pomodoro',
      extractData: (_) => {},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:focus\s+timer)\s*(\d+)?$', caseSensitive: false),
      taskType: 'timer_pomodoro',
      extractData: (m) => {'minutes': int.tryParse(m.group(1) ?? '') ?? 25},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:cancel|stop)\s+timer$', caseSensitive: false),
      taskType: 'timer_cancel',
      extractData: (_) => {},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:timer\s+status|how\s+much\s+time\s+left)$', caseSensitive: false),
      taskType: 'timer_status',
      extractData: (_) => {},
    ),

    // ─── Calculator ────────────────────────────────────────
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:calculate|calc|compute|what\s+is)\s+(.+)$', caseSensitive: false),
      taskType: 'calculator_eval',
      extractData: (m) => {'expression': m.group(1)!.trim()},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(\d+(?:\.\d+)?)\s*%\s*(?:of)\s+(\d+(?:\.\d+)?)$', caseSensitive: false),
      taskType: 'calculator_eval',
      extractData: (m) => {'expression': '${m.group(1)}% of ${m.group(2)}'},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:convert\s+)?(\d+(?:\.\d+)?)\s*(\w+)\s+(?:to|in|into)\s+(\w+)$', caseSensitive: false),
      taskType: 'calculator_convert',
      extractData: (m) => {'value': double.parse(m.group(1)!), 'from': m.group(2)!, 'to': m.group(3)!},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:what\s+time\s+(?:is\s+it\s+)?in)\s+(.+)$', caseSensitive: false),
      taskType: 'calculator_timezone',
      extractData: (m) => {'location': m.group(1)!.trim()},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:how\s+many\s+days?\s+(?:until|till|to))\s+(.+)$', caseSensitive: false),
      taskType: 'calculator_date_math',
      extractData: (m) => {'target': m.group(1)!.trim(), 'operation': 'days_until'},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(\d+)\s+days?\s+from\s+(?:now|today)$', caseSensitive: false),
      taskType: 'calculator_date_math',
      extractData: (m) => {'days': int.parse(m.group(1)!), 'operation': 'days_from_now'},
    ),

    // ─── Music ─────────────────────────────────────────────
    // Note: "play music" must come BEFORE generic "play X" to match first
    DomainIntentPatternLocal(
      pattern: RegExp(r'^play\s+music$', caseSensitive: false),
      taskType: 'music_play',
      extractData: (_) => {},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:pause|stop)\s*(?:music|playback)?$', caseSensitive: false),
      taskType: 'music_pause',
      extractData: (_) => {},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:resume)\s*(?:music|playback)?$', caseSensitive: false),
      taskType: 'music_play',
      extractData: (_) => {},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:next\s+(?:song|track)|skip)$', caseSensitive: false),
      taskType: 'music_next',
      extractData: (_) => {},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:previous\s+(?:song|track)|prev|go\s+back)$', caseSensitive: false),
      taskType: 'music_previous',
      extractData: (_) => {},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r"^(?:what'?s?\s+playing|now\s+playing|current\s+(?:song|track))$", caseSensitive: false),
      taskType: 'music_now_playing',
      extractData: (_) => {},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^play\s+(?:playlist\s+)?(.+?)(?:\s+playlist)?$', caseSensitive: false),
      taskType: 'music_playlist',
      extractData: (m) => {'playlist': m.group(1)!.trim()},
      confidence: 0.8,
    ),

    // ─── Reminders ─────────────────────────────────────────
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:remind\s+me\s+to|add\s+(?:a\s+)?reminder(?:\s+to)?)\s+(.+?)(?:\s+(?:at|by|on)\s+(.+))?$', caseSensitive: false),
      taskType: 'reminders_add',
      extractData: (m) => {'title': m.group(1)!.trim(), 'due': m.group(2)},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^add\s+(.+?)\s+to\s+(?:my\s+)?(?:shopping\s+list|groceries|grocery\s+list)$', caseSensitive: false),
      taskType: 'reminders_add',
      extractData: (m) => {'title': m.group(1)!.trim(), 'list': 'Shopping'},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:show|list|my|check)\s*(?:my\s+)?reminders?$', caseSensitive: false),
      taskType: 'reminders_list',
      extractData: (_) => {},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:complete|finish|done\s+with|mark\s+.+?\s+(?:as\s+)?done)\s*(.+)?$', caseSensitive: false),
      taskType: 'reminders_complete',
      extractData: (m) => {'title': m.group(1)?.trim() ?? ''},
    ),

    // ─── Calendar ──────────────────────────────────────────
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:schedule|add\s+(?:an?\s+)?(?:event|meeting|appointment)|create\s+(?:an?\s+)?(?:event|meeting))\s+(?:about\s+|titled?\s+|for\s+|with\s+)?(.+?)(?:\s+(?:at|on|for|tomorrow|today)\s*(.+))?$', caseSensitive: false),
      taskType: 'calendar_add_event',
      extractData: (m) => {'title': m.group(1)!.trim(), 'datetime_raw': m.group(2) ?? ''},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^meeting\s+(?:with\s+)?(.+?)\s+(today|tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?:\s+(?:at\s+)?(.+))?$', caseSensitive: false),
      taskType: 'calendar_add_event',
      extractData: (m) => {'title': 'Meeting with ${m.group(1)!.trim()}', 'datetime_raw': '${m.group(2)} ${m.group(3) ?? ''}'.trim()},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r"^(?:what'?s?\s+on\s+my\s+(?:calendar|schedule)|my\s+(?:calendar|schedule|agenda)(?:\s+(?:for\s+)?(today|tomorrow))?|agenda(?:\s+(?:for\s+)?(today|tomorrow))?)$", caseSensitive: false),
      taskType: 'calendar_list_events',
      extractData: (m) => {'date_raw': m.group(1) ?? m.group(2) ?? 'today'},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:cancel|delete|remove)\s+(?:the\s+)?(?:meeting|event|appointment)\s+(?:about\s+|titled?\s+)?(.+)$', caseSensitive: false),
      taskType: 'calendar_delete_event',
      extractData: (m) => {'title': m.group(1)!.trim()},
    ),

    // ─── Notes ─────────────────────────────────────────────
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:create|make|new)\s+(?:a\s+)?note\s+(?:about\s+|titled?\s+)?(.+)$', caseSensitive: false),
      taskType: 'notes_create',
      extractData: (m) => {'title': m.group(1)!.trim(), 'body': m.group(1)!.trim()},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^note:\s*(.+)$', caseSensitive: false),
      taskType: 'notes_create',
      extractData: (m) => {'title': m.group(1)!.trim(), 'body': m.group(1)!.trim()},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:search|find)\s+notes?\s+(?:about\s+|for\s+)?(.+)$', caseSensitive: false),
      taskType: 'notes_search',
      extractData: (m) => {'query': m.group(1)!.trim()},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:show|list)\s+(?:my\s+)?(?:recent\s+)?notes$', caseSensitive: false),
      taskType: 'notes_list',
      extractData: (_) => {},
    ),

    // ─── Weather ───────────────────────────────────────────
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:weather|temperature|temp)(?:\s+(?:in|for|at)\s+(.+?))?(?:\s+tomorrow)?$', caseSensitive: false),
      taskType: 'weather_current',
      extractData: (m) => {'location': m.group(1) ?? ''},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r"^(?:what'?s?\s+the\s+weather)(?:\s+(?:in|for|at)\s+(.+?))?(?:\s+(today|tomorrow))?$", caseSensitive: false),
      taskType: 'weather_current',
      extractData: (m) => {'location': m.group(1) ?? '', 'day': m.group(2) ?? 'today'},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:is\s+it\s+going\s+to\s+rain|will\s+it\s+rain)(?:\s+(today|tomorrow))?$', caseSensitive: false),
      taskType: 'weather_current',
      extractData: (m) => {'day': m.group(1) ?? 'today'},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:weather\s+)?forecast(?:\s+(?:for\s+)?(.+))?$', caseSensitive: false),
      taskType: 'weather_forecast',
      extractData: (m) => {'location': m.group(1) ?? ''},
    ),

    // ─── Email ─────────────────────────────────────────────
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:email|send\s+(?:an?\s+)?email\s+to)\s+(\S+@\S+)\s+(?:about|re|regarding)\s+(.+)$', caseSensitive: false),
      taskType: 'email_compose',
      extractData: (m) => {'to': m.group(1)!, 'subject': m.group(2)!.trim()},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:email|send\s+(?:an?\s+)?email\s+to)\s+(.+?)\s+(?:about|re|regarding)\s+(.+)$', caseSensitive: false),
      taskType: 'email_compose',
      extractData: (m) => {'to': m.group(1)!.trim(), 'subject': m.group(2)!.trim()},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:check\s+(?:my\s+)?email|any\s+new\s+mail|unread\s+emails?|inbox)$', caseSensitive: false),
      taskType: 'email_check',
      extractData: (_) => {},
    ),

    // ─── Contacts ──────────────────────────────────────────
    DomainIntentPatternLocal(
      pattern: RegExp(r"^(?:find\s+contact|look\s+up|search\s+contacts?\s+for|what'?s?\s+.+?'?s?\s+(?:number|phone|email))\s+(.+)$", caseSensitive: false),
      taskType: 'contacts_find',
      extractData: (m) => {'name': m.group(1)!.trim()},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:call|phone|dial|facetime)\s+(.+)$', caseSensitive: false),
      taskType: 'contacts_call',
      extractData: (m) => {'name': m.group(1)!.trim()},
    ),

    // ─── Messages ──────────────────────────────────────────
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:send\s+(?:a\s+)?message|text|imessage)\s+(?:to\s+)?(.+?)\s+(?:saying|that|:)\s+(.+)$', caseSensitive: false),
      taskType: 'messages_send',
      extractData: (m) => {'recipient': m.group(1)!.trim(), 'message': m.group(2)!.trim()},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:message|text)\s+(.+)$', caseSensitive: false),
      taskType: 'messages_send',
      extractData: (m) => {'recipient': m.group(1)!.trim(), 'message': ''},
      confidence: 0.7,
    ),

    // ─── Translation ───────────────────────────────────────
    DomainIntentPatternLocal(
      pattern: RegExp(r'^translate\s+(.+?)\s+(?:to|into)\s+(\w+)$', caseSensitive: false),
      taskType: 'translation_translate',
      extractData: (m) => {'text': m.group(1)!.trim(), 'target_language': m.group(2)!.trim()},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^how\s+do\s+you\s+say\s+(.+?)\s+in\s+(\w+)$', caseSensitive: false),
      taskType: 'translation_translate',
      extractData: (m) => {'text': m.group(1)!.trim(), 'target_language': m.group(2)!.trim()},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(.+?)\s+in\s+(spanish|french|german|japanese|chinese|korean|italian|portuguese|russian|arabic|hindi)$', caseSensitive: false),
      taskType: 'translation_translate',
      extractData: (m) => {'text': m.group(1)!.trim(), 'target_language': m.group(2)!.trim()},
    ),

    // ─── Files & Media ─────────────────────────────────────
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:compress|zip)\s+(?:images?\s+in\s+|files?\s+in\s+)?(.+)$', caseSensitive: false),
      taskType: 'files_compress',
      extractData: (m) => {'path': _resolveDir(m.group(1)!.trim())},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^convert\s+(\w+)\s+to\s+(\w+)(?:\s+in\s+(.+))?$', caseSensitive: false),
      taskType: 'files_convert',
      extractData: (m) => {'from_format': m.group(1)!, 'to_format': m.group(2)!, 'path': m.group(3) != null ? _resolveDir(m.group(3)!) : '~/Desktop'},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:organize|sort\s+files?\s+in)\s+(.+)$', caseSensitive: false),
      taskType: 'files_organize',
      extractData: (m) => {'path': _resolveDir(m.group(1)!.trim())},
    ),

    // ─── Media Creation ─────────────────────────────────
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:animate|create\s+(?:a\s+)?(?:video|animation)\s+(?:from|of|with))\s+(?:this\s+)?(?:photo|picture|image)$', caseSensitive: false),
      taskType: 'media_animate_photo',
      extractData: (_) => {'effect': 'ken_burns'},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:make|create)\s+(?:an?\s+)?(?:ad|advertisement|promo(?:tional)?(?:\s+video)?)\s+(?:from|with|of)\s+(?:this\s+)?(?:photo|picture|image)$', caseSensitive: false),
      taskType: 'media_animate_photo',
      extractData: (_) => {'effect': 'ken_burns', 'style': 'ad', 'duration': 8},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:create|make)\s+(?:a\s+)?(?:video\s+)?slideshow(?:\s+(?:from|with)\s+(?:these\s+)?(?:photos|images|pictures))?$', caseSensitive: false),
      taskType: 'media_create_slideshow',
      extractData: (_) => {'transition': 'fade'},
    ),

    // ─── AI Video Generation ────────────────────────────
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:generate|create)\s+(?:an?\s+)?(?:ai|cinematic|professional)\s+video\s+(?:from|of|with)\s+(?:this\s+)?(?:photo|picture|image)$', caseSensitive: false),
      taskType: 'media_ai_generate_video',
      extractData: (_) => {'style': 'cinematic'},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:make|create)\s+(?:an?\s+)?(?:tiktok|social\s+media|ad|commercial)\s+video\s+(?:from|with|of)\s+(?:this\s+)?(?:photo|picture|image)$', caseSensitive: false),
      taskType: 'media_ai_generate_video',
      extractData: (_) => {'style': 'adPromo'},
    ),
    DomainIntentPatternLocal(
      pattern: RegExp(r'^(?:generate|create)\s+(?:an?\s+)?(?:ai\s+)?video\s+(?:from|of|with)\s+(?:this\s+)?(?:photo|picture|image)\s+(?:using|with|via)\s+(replicate|runway|kling|luma)$', caseSensitive: false),
      taskType: 'media_ai_generate_video',
      extractData: (m) => {'provider': m.group(1)!.toLowerCase(), 'style': 'cinematic'},
    ),
  ];
}

/// Resolve common directory aliases to full paths
String _resolveDir(String input) {
  final lower = input.toLowerCase().trim();
  switch (lower) {
    case 'downloads':
    case 'my downloads':
      return '~/Downloads';
    case 'desktop':
    case 'my desktop':
      return '~/Desktop';
    case 'documents':
    case 'my documents':
      return '~/Documents';
    case 'pictures':
    case 'photos':
    case 'my pictures':
      return '~/Pictures';
    default:
      return input;
  }
}
