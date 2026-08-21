export type OpenCLIConfigValue = string | number | boolean | OpenCLIConfigValue[] | OpenCLIConfigObject;

export type OpenCLIConfigObject = { [key: string]: OpenCLIConfigValue };

export type OpenCLIOptions = {
  opencliPathOverride?: string;
  baseUrl?: string;
  apiKey?: string;
  /**
   * Additional `--config key=value` overrides to pass to the OpenCLI CLI.
   *
   * Provide a JSON object and the SDK will flatten it into dotted paths and
   * serialize values as TOML literals so they are compatible with the CLI's
   * `--config` parsing.
   */
  config?: OpenCLIConfigObject;
  /**
   * Environment variables passed to the OpenCLI CLI process. When provided, the SDK
   * will not inherit variables from `process.env`.
   */
  env?: Record<string, string>;
};
