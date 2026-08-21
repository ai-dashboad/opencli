import { OpenCLIOptions } from "./opencliOptions";
import { OpenCLIExec } from "./exec";
import { Thread } from "./thread";
import { ThreadOptions } from "./threadOptions";

/**
 * OpenCLI is the main class for interacting with the OpenCLI agent.
 *
 * Use the `startThread()` method to start a new thread or `resumeThread()` to resume a previously started thread.
 */
export class OpenCLI {
  private exec: OpenCLIExec;
  private options: OpenCLIOptions;

  constructor(options: OpenCLIOptions = {}) {
    const { opencliPathOverride, env, config } = options;
    this.exec = new OpenCLIExec(opencliPathOverride, env, config);
    this.options = options;
  }

  /**
   * Starts a new conversation with an agent.
   * @returns A new thread instance.
   */
  startThread(options: ThreadOptions = {}): Thread {
    return new Thread(this.exec, this.options, options);
  }

  /**
   * Resumes a conversation with an agent based on the thread id.
   * Threads are persisted in ~/.opencli/sessions.
   *
   * @param id The id of the thread to resume.
   * @returns A new thread instance.
   */
  resumeThread(id: string, options: ThreadOptions = {}): Thread {
    return new Thread(this.exec, this.options, options, id);
  }
}
