# ADR 0041 — The blog uploads by rsync or SFTP, not FTP

**Status:** accepted · 2026-10-17 (built overnight; confirmed by the owner 2026-10-17 after uploading by SFTP). Changes part of meeting 2026-10-16-2056, § 8.

## Context

The meeting of 2026-10-16-2056 (§ 8) planned the micro-blog's upload "by FTP or FTPS (OTP's own `ftp` application, no new dependency)", beside rsync and a mounted folder (sshfs). When it was built (R74), OTP 29, the version Agendum runs on, turned out to deprecate the whole `ftp` application: every call warns "It will be removed in OTP 30. Legacy protocol support will be dropped in OTP-30, use more modern approach for file transfer as for instance SFTP". `mix check` treats warnings as errors, and the warning cannot be silenced honestly (a dynamic call would only hide it), and in OTP 30 the code would stop working.

## Decision

- The blog uploads by **rsync over ssh** or by **SFTP**, through OTP's own `ssh` application (`:ssh_sftp`): no new dependency (ADR 0021), and not deprecated.
- SFTP uses the person's ssh keys (`~/.ssh`, the server's key in `known_hosts` as for ssh itself); when the server refuses them, Agendum asks for a password in a prompt shown as stars, never kept, never logged. A password in `~/.netrc` is used too.
- A server that only takes FTP is reached through a mounted folder (the folder may be anywhere, `curlftpfs` or the like), as sshfs is.

## Consequences

- The Publish box offers Upload: None, rsync over ssh, SFTP.
- SFTP is tested for real: the test runs an SFTP server of OTP's own on a free port (`test/agendum/publish_test.exs`).
- If the owner wants FTP itself back, it needs a package (an ADR 0021 review) or OTP's `ftp` until OTP 30.
