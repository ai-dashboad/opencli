# opencli-linux-sandbox

This crate is responsible for producing:

- a `opencli-linux-sandbox` standalone executable for Linux that is bundled with the Node.js version of the OpenCLI CLI
- a lib crate that exposes the business logic of the executable as `run_main()` so that
  - the `opencli-exec` CLI can check if its arg0 is `opencli-linux-sandbox` and, if so, execute as if it were `opencli-linux-sandbox`
  - this should also be true of the `opencli` multitool CLI
