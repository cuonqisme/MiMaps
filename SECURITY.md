# Security

- Do not commit API keys, certificates, private keys, provisioning profiles, App Store Connect keys, or exported IPAs.
- Restrict the Google API key by iOS Bundle ID and API allowlist.
- Store release credentials only in GitHub Actions encrypted secrets.
- Rotate a credential immediately if it appears in a commit, log, issue, or artifact.
- Release CI uses a temporary keychain and deletes imported signing assets even after failure.
- Artifacts may contain signed application binaries; limit repository and Actions access appropriately.
- The app has no custom backend, account system, analytics SDK, or stored navigation history.

Report a vulnerability privately to the repository owner rather than opening a public issue containing exploit details or secrets.
