# php-docker

**PHP + Apache + mod_php** Docker images for legacy applications that have to keep
running without a rewrite: from PHP 8.5 down to PHP 5.2.

Every image lets you set the UID/GID of the `www-data` user to match the site's
account on the host. Files mounted from the host stay writable for that user over
SCP/SFTP, and files written by the application stay owned by them.

- One shared, parameterized `Dockerfile` for PHP 5.6 and 7.0 – 8.5
- Hardened defaults: no directory listing, no `.git`/`.env` exposure, strict
  session cookies, locked-down ImageMagick policy, minimal information disclosure
- Runtime configuration through environment variables, no rebuild needed
- Multiple virtual hosts per container through a mounted config directory
- `RUN_AS=www-data` for running `composer`, `wp-cli` and similar tools as the site user

---

## Support status

> [!WARNING]
> **Some images are deprecated and receive no support of any kind.**
> Their base distributions are end-of-life and get no security updates.
> Upstream PHP stopped supporting those PHP versions years ago. The images are
> provided **as is**, only so that legacy applications that cannot be migrated
> keep running. Known vulnerabilities in them **will not be fixed**. Plan a
> migration, and never expose them to the internet without extra isolation.

Patch status for **CVE-2026-109618** and **CVE-2026-109619**, as of 21 October 2026:

| Tag | PHP | Base OS | Upstream PHP | OS security updates | CVE-2026-109618 / 109619 | Status |
|-----|-----|---------|--------------|---------------------|--------------------------|--------|
| `8.5`, `8` | 8.5 | Ubuntu 26.04 LTS | supported | yes | ✅ patched | ✅ **Supported** |
| `8.4` | 8.4 | Debian 13 (trixie) | supported | yes | ✅ patched | ✅ **Supported** |
| `8.2` | 8.2 | Debian 12 (bookworm) | security fixes only, until end of 2026 | yes (Debian LTS, until June 2028) | ✅ patched | ✅ **Supported** |
| `8.1` | 8.1 | Ubuntu 22.04 LTS | end of life | yes (until 2027) | ✅ patched | ✅ **Supported** (distribution backports) |
| `7.4`, `7` | 7.4.33 ([Sury](https://packages.sury.org/php/)) | Debian 13 (trixie) | end of life | yes | ✅ patched (`7.4.33-31`) | ⚠️ **Legacy**, patched via Sury |
| `7.4-mongodb1.18` | 7.4.33 (Sury) | Debian 13 (trixie) | end of life | yes | ✅ patched (`7.4.33-31`) | ⚠️ **Legacy**, patched via Sury |
| `5.6`, `5` | 5.6.40 (Sury) | Debian 13 (trixie) | end of life | yes | ✅ patched (`5.6.40-104`) | ⚠️ **Legacy**, patched via Sury |
| `7.2` | 7.2 | Ubuntu 18.04 | end of life | no (paid Ubuntu Pro only) | ❌ **not patched** | ⛔ **Deprecated, unsupported** |
| `7.0` | 7.0 | Ubuntu 16.04 | end of life | no (paid Ubuntu Pro only) | ❌ **not patched** | ⛔ **Deprecated, unsupported** |
| `5.5` | 5.5 | Ubuntu 14.04 | end of life | no | ❌ **not patched** | ⛔ **Deprecated, unsupported** |
| `5.4` | 5.4 | Debian 7 (wheezy, archived) | end of life | no | ❌ **not patched** | ⛔ **Deprecated, unsupported** |
| `5.3` | 5.3 | Debian 6 (squeeze, archived) | end of life | no | ❌ **not patched** | ⛔ **Deprecated, unsupported** |
| `5.2` | 5.2 | Debian 5 (lenny, archived) | end of life | no | ❌ **not patched** | ⛔ **Deprecated, unsupported** |

**What the statuses mean**

- ✅ **Supported**: PHP and the OS packages get security fixes from the
  distribution. Rebuild regularly to pick them up (see [Building](#building)).
- ⚠️ **Legacy, patched via Sury**: the PHP branch is end-of-life upstream, but
  [packages.sury.org](https://packages.sury.org/php/) still ships free security
  backports. As of October 2026 it is the only free source of fixes for
  CVE-2026-109618/109619 on PHP 7.4 and 5.6. Fixes depend on that one
  maintainer, so treat these images as a bridge to migration.
- ⛔ **Deprecated, unsupported**: nothing gets security fixes, not PHP, not
  Apache, not OpenSSL or any other system library. These images are frozen.
  They build only from archived repositories, which may disappear at any time.

**If you must run a deprecated image:**

- Keep the built-in mitigation for CVE-2026-109619. These images default to
  `APACHE_KEEPALIVE=Off` and `APACHE_MAX_REQUESTS_PER_CHILD=1`, so every request
  runs in a fresh process and no state carries over from one request to the next.
  Do not override these values (see [Apache](#apache)).
- Keep `session.upload_progress.enabled = 0` (the default).
- Put the container behind a reverse proxy or WAF. Restrict network access, and
  apply the runtime hardening from [Production hardening](#production-hardening).
- Run `docker save` on the built images and keep the archives (see
  [Archival images](#archival-images)).

---

## Images

| Tag | PHP | Base image | Apache | Dockerfile |
|-----|-----|------------|--------|------------|
| `narel/php:8.5`, `:8` | 8.5 | `ubuntu:26.04` | 2.4 | `Dockerfile` |
| `narel/php:8.4` | 8.4 | `debian:trixie` | 2.4 | `Dockerfile` |
| `narel/php:8.2` | 8.2 | `debian:bookworm` | 2.4 | `Dockerfile` |
| `narel/php:8.1` | 8.1 | `ubuntu:22.04` | 2.4 | `Dockerfile` |
| `narel/php:7.4`, `:7` | 7.4 (Sury) | `debian:trixie` | 2.4 | `Dockerfile` |
| `narel/php:7.4-mongodb1.18` | 7.4 (Sury) | `debian:trixie` | 2.4 | `Dockerfile.php7.4-mongodb1.18` |
| `narel/php:7.2` | 7.2 | `ubuntu:18.04` | 2.4 | `Dockerfile` |
| `narel/php:7.0` | 7.0 | `ubuntu:16.04` | 2.4 | `Dockerfile` |
| `narel/php:5.6`, `:5` | 5.6 (Sury) | `debian:trixie` | 2.4 | `Dockerfile` |
| `narel/php:5.5` | 5.5 | `ubuntu:14.04` | 2.4 | `Dockerfile.php5.5` |
| `narel/php:5.4` | 5.4 | `debian:wheezy` | 2.2 | `Dockerfile.php5.4` |
| `narel/php:5.3` | 5.3 | `sstrigler/squeeze` | 2.2 | `Dockerfile.php5.3` |
| `narel/php:5.2` | 5.2 | `debian/eol:lenny` | 2.2 | `Dockerfile.php5.2` |

PHP 5.6 and 7.0 – 8.5 share a single `Dockerfile` parameterized with `--build-arg`.
The other PHP 5.x images have their own files, because their package names and
Apache versions differ. PHP 7.4 and 5.6 come from the Sury repository, all other
versions from the base distribution (see [PHP 7.4 and 5.6 from Sury](#php-74-and-56-from-sury)).

### Repository layout

```
.
├── Dockerfile                       # shared: PHP 5.6, 7.0 – 8.5
├── Dockerfile.php7.4-mongodb1.18    # PHP 7.4 with mongodb 1.18.0
├── Dockerfile.php5.{2,3,4,5}        # legacy PHP 5.x images
├── build.sh                         # builds, tags and pushes images
├── run.sh                           # shared entrypoint
├── common/                          # Apache, PHP and ImageMagick configuration
├── pecl/                            # vendored PECL tarballs for PHP 5.x builds
├── php5.3/                          # apt configuration for the squeeze image
└── php8.5-node/                     # narel/php:8.5 + Node.js, yarn, wkhtmltopdf
```

---

## Building

```sh
./build.sh                            # all versions
./build.sh 8.5 7.4                    # selected versions only
PUSH=1 ./build.sh 8.5                 # build and push
PLATFORM=linux/amd64 ./build.sh 5.3   # old base images are amd64 only
NO_PULL=1 ./build.sh 8.2              # do not refresh the base image
NO_CACHE=1 ./build.sh 8.5             # build without layer cache
REGISTRY=myorg/php ./build.sh 8.5     # use a different image name
```

A failure in one version does not stop the others. A summary is printed at the
end, and the exit code is non-zero if anything failed.

> [!IMPORTANT]
> **After a security fix, rebuild with `NO_CACHE=1`.** `--pull` refreshes only
> the base image. If the base image has not changed, the `apt-get install`
> layer comes from the cache and the image keeps the old packages, even though
> the repository already has new ones.
>
> Check the installed version with:
> `docker run --rm --entrypoint dpkg narel/php:8.5 -l 'libapache2-mod-php*'`

### PHP 5.x images need a separate builder

On recent kernels, the default BuildKit **hangs** on `apt-get update` from the
jessie/wheezy/lenny era: the process spins forever at 100% CPU. The same command
under `docker run` finishes in a second, so the problem is the BuildKit sandbox,
not the images themselves. Workaround: create, once, a builder that runs an
older BuildKit in a container:

```sh
docker buildx create --name oldbuilder --driver docker-container \
    --driver-opt image=moby/buildkit:v0.12.5
BUILDER=oldbuilder ./build.sh 5.5 5.4 5.3 5.2
```

PHP 5.6 and 7.0 – 8.5 build fine without `BUILDER`.

### Disk space

The full set of 13 images takes about 9 GB, plus a layer cache that grows to
several GB. `docker builder prune -f` frees the cache only and **does not touch
images**. `docker system prune` can delete finished images.

### GitHub Actions

`.github/workflows/build.yml` builds every version in a separate job, in
parallel. It runs on pushes to `main` and on pull requests that touch the
Dockerfiles, `build.sh`, `common/`, `pecl/` or `php5.3/`. Only build, no push.

To build and push by hand: **Actions → Build images → Run workflow**. Inputs:

- `versions`: space separated, for example `8.5 7.4` (empty = all)
- `push`: push to the registry (see below)
- `no_cache`: build without layer cache, after security fixes

Pushing is configured in **Settings → Secrets and variables → Actions**:

| Name | Kind | Example | Meaning |
|------|------|---------|---------|
| `REGISTRY` | variable | `registry.example.com/php` | image name, with the registry host; default `narel/php` (Docker Hub) |
| `REGISTRY_HOST` | variable | `registry.example.com` | host to log in to; empty = Docker Hub |
| `REGISTRY_USERNAME` | secret | `ci-bot` | registry user |
| `REGISTRY_PASSWORD` | secret | | password or access token |

The registry must be reachable from GitHub-hosted runners, over HTTPS with a
publicly trusted certificate.

### Automatic rebuilds

`.github/workflows/rebuild.yml` runs every day at 04:17 UTC (and on demand
from the Actions tab). For every version it compares the digest of the base
image (`ubuntu:26.04`, `debian:trixie`, …) with the digest recorded in the
pushed image, in the `org.opencontainers.image.base.digest` label that
`build.sh` sets. Only the versions whose base image changed are rebuilt and
pushed. An image without the label is rebuilt once, which adds it.

`./build.sh --base 8.5` prints the base image of a version.

This catches new base images only. Security fixes that reach Debian, Ubuntu or
Sury between base image releases still need a manual run with `no_cache`.

---

## Running

```sh
docker run -d --name my-site \
  -p 8080:8000 \
  -e APACHE_UID=$(id -u owner) \
  -e APACHE_GID=$(id -g owner) \
  -v /home/owner/www:/var/www/html \
  narel/php:8.2
```

Apache listens on port **8000**, an unprivileged port. The container still
starts as root, because changing the UID needs root. Apache then drops
privileges to `www-data`.

---

## Environment variables

### User and directories

| Variable | Default | Description |
|----------|---------|-------------|
| `APACHE_UID` | `1000` | UID of the `www-data` user in the container |
| `APACHE_GID` | `1000` | GID of the `www-data` group |
| `DOCUMENT_ROOT` | `/var/www/html` | application directory |
| `TZ` | `Europe/Warsaw` | system time zone **and** PHP `date.timezone` |

### Apache

| Variable | Default | Description |
|----------|---------|-------------|
| `APACHE_SERVER_NAME` | `localhost` | `ServerName` |
| `APACHE_OPTIONS` | `-Indexes +FollowSymLinks` | `Options` for `DOCUMENT_ROOT` |
| `APACHE_TRUSTED_PROXIES` | private networks | trusted proxies for `X-Forwarded-For` |
| `APACHE_MAX_WORKERS` | `32` | `MaxRequestWorkers` / `MaxClients` |
| `APACHE_START_SERVERS` | `2` | `StartServers` |
| `APACHE_MIN_SPARE` | `2` | `MinSpareServers` |
| `APACHE_MAX_SPARE` | `5` | `MaxSpareServers` |
| `APACHE_MAX_REQUESTS_PER_CHILD` | `500`, `1` on unpatched images | process recycling (legacy apps tend to leak memory) |
| `APACHE_KEEPALIVE` | `On`, `Off` on unpatched images | `KeepAlive` (`On`/`Off`) |

**Unpatched images (7.2, 7.0, 5.5 and older)** default to
`APACHE_KEEPALIVE=Off` and `APACHE_MAX_REQUESTS_PER_CHILD=1`. Every request runs
in a fresh process, so state left behind by one request cannot reach the next
one (CVE-2026-109619). Setting only `APACHE_MAX_REQUESTS_PER_CHILD=1` is not
enough: Apache counts connections, not requests, and with KeepAlive a single
connection carries up to 100 requests. The cost is a fork and a PHP start-up
per request.

**Optional layer: block uploads in Apache.** For applications that never accept
file uploads, `common/block-multipart.conf` rejects `multipart/form-data`
requests before they reach PHP. It is not enabled in any image by default; mount
it yourself (see the comment in the file). It is mainly a safety net in case
someone re-enables `session.upload_progress.enabled = 1` without knowing why it
was turned off (see [Settings you may need to relax](#settings-you-may-need-to-relax)).
It does not help against CVE-2026-109618, which goes through memory exhaustion
rather than uploads.

### PHP

| Variable | Default | Description |
|----------|---------|-------------|
| `OPEN_BASEDIR` | (disabled) | e.g. `/var/www/html:/tmp`, confines the application |
| `PHP_MEMORY_LIMIT` | `256M` (from `php.conf`) | `memory_limit` |
| `PHP_MAX_EXECUTION_TIME` | `60` | `max_execution_time` |
| `PHP_UPLOAD_MAX_FILESIZE` | `32M` | `upload_max_filesize` |
| `PHP_POST_MAX_SIZE` | `32M` | `post_max_size` |

### Mail (ssmtp)

| Variable | Default | Description |
|----------|---------|-------------|
| `SSMTP` | `true` | generate `/etc/ssmtp/ssmtp.conf` at start-up |
| `SSMTP_MAILHUB` | `192.168.0.1` | SMTP relay (`host` or `host:port`) |
| `SSMTP_DOMAIN` | `example.com` | rewrite domain |
| `SSMTP_ROOT` | | address that receives mail for system users |
| `SSMTP_TLS` | | `true` enables TLS and STARTTLS |
| `SSMTP_AUTH_USER` | | SMTP user name |
| `SSMTP_AUTH_PASS` | | SMTP password (the file is readable by root and the `mail` group only) |

---

## Extension points

| Path | Behavior |
|------|----------|
| `/etc/php_config/*.ini` | copied into `conf.d/` at start-up. Use the `99-` prefix to override the image's settings |
| `/etc/apache_config/` | copied into `/etc/apache2/` at start-up |
| `/etc/apache2/conf.d/*.conf` | loaded at the end of `apache2.conf`: virtual hosts, `Alias`, `<Directory>` (see below) |
| `/startup.d/*.sh` | executed before Apache starts (an empty directory is fine) |

### Multiple sites (virtual hosts) in one container

Mount a directory of `*.conf` files at `/etc/apache2/conf.d`. No rebuild needed:

```sh
docker run -d -p 8080:8000 \
  -v /home/site/www:/home/site/www \
  -v /home/site/apache:/etc/apache2/conf.d:ro \
  narel/php:8.5
```

```apache
# The image grants access to DOCUMENT_ROOT only. Other directories need this.
<Directory /home/site/www>
    Options -Indexes +FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>

# The first virtual host is the default one: it receives requests with an unknown Host header.
<VirtualHost *:8000>
    DocumentRoot /home/site/www/frontend/web
</VirtualHost>
<VirtualHost *:8000>
    ServerName admin.example.com
    DocumentRoot /home/site/www/backend/web
</VirtualHost>
```

- Virtual hosts inherit the image's settings: the `.ht*`/`.env`/`.git` blocks,
  `remoteip` and logging.
- Mount a directory, not a single file. Editors that save through a new file
  (vim, `sed -i`) leave the old version of a bind-mounted file in the container.
- After a change, run `docker exec site apache2ctl -t && docker exec site apache2ctl graceful`.
  A broken file prevents the container from starting.
- With `OPEN_BASEDIR`, add these directories too, e.g. `/home/site/www:/tmp`.
- Apache 2.2 (PHP 5.2 – 5.4): add `NameVirtualHost *:8000` at the top of the file.

---

## Running commands as the site user

The entrypoint runs any command you pass. You can run `composer`, `wp-cli` or
other scripts with the UID already set:

```sh
docker run --rm -e APACHE_UID=1001 -e APACHE_GID=1001 -e RUN_AS=www-data \
  -v /home/owner/www:/var/www/html -w /var/www/html \
  narel/php:8.2 php composer.phar install
```

Without `RUN_AS=www-data`, the command runs as root and leaves root-owned files
in the mounted directory. `RUN_AS` needs `setpriv` (util-linux 2.31+), so it
works on 5.6 and on 7.2 and newer. `HOME` is then set to `/tmp/www-data-home`,
because composer, yarn and npm keep their cache in `~`.

---

## Production hardening

The container has to start as root (to change the UID and then drop privileges),
so compensate at runtime:

```yaml
services:
  site:
    image: narel/php:8.2
    security_opt: ["no-new-privileges:true"]
    cap_drop: [ALL]
    cap_add: [CHOWN, SETUID, SETGID, DAC_OVERRIDE, FOWNER]
    pids_limit: 200
    mem_limit: 1g
    environment:
      OPEN_BASEDIR: /var/www/html:/tmp
```

`OPEN_BASEDIR` matters most here: a web shell uploaded into one application
cannot escape that application's directory.

---

## Settings you may need to relax

The images are hardened by default. If a legacy application stops working,
check these first:

1. **`session.cookie_samesite = Lax`** breaks sessions when an external payment
   gateway returns with a POST. Fix it with a file in `/etc/php_config/`:
   `echo 'session.cookie_samesite = None' > 99-local.ini`
2. **`session.cookie_httponly = 1`** breaks applications that read the session
   cookie from JavaScript.
3. **`Options -Indexes`** breaks sites that list a directory on purpose. Use
   `Options +Indexes` in `.htaccess`, or `-e APACHE_OPTIONS="+Indexes +FollowSymLinks"`.
4. **ImageMagick policy**: installed only where the distribution shipped a
   permissive default. It blocks PDF, PS, SVG and others; see
   `common/imagemagick-policy.xml`.
5. **`APACHE_MAX_WORKERS=32`**: raise it under heavy traffic. Keep in mind that
   `32 × memory_limit` is the upper bound for memory use.
6. **`session.upload_progress.enabled = 0`**: disabled because of
   CVE-2026-109619. If the application shows a session-based upload progress
   bar, use `echo 'session.upload_progress.enabled = 1' > 99-local.ini`. On
   unpatched images (7.2, 7.0, 5.5 and older), first make sure the application
   really needs it, because re-enabling it reopens the same attack vector.
7. **`fatal_error_backtraces = 0`** (PHP 8.5 only), for the same reason. Fatal
   errors are logged without a stack trace; enable it temporarily for debugging.

---

## Notes

### PHP 7.4 and 5.6 from Sury

The `7.4`, `7.4-mongodb1.18` and `5.6` (`:5`) images are based on `debian:trixie`,
with PHP from [packages.sury.org](https://packages.sury.org/php/). Only Sury ships
free fixes for CVE-2026-109618/109619 for these branches: `7.4.33-31` and
`5.6.40-104` (21 October 2026).

| | before | now |
|-|--------|-----|
| 7.4 | 7.4.3 from Ubuntu 20.04 (fixes only through Ubuntu Pro) | 7.4.33 from Sury |
| 5.6 | 5.6.40 from Debian 8 (archived, last build from 2020) | 5.6.40 from Sury |

- The new base also upgrades libraries: OpenSSL to 3.x (old TLS servers may
  reject connections), ImageMagick 6 → 7, imagick 3.8, redis 6.x (7.4).
  Test the site before deploying.
- 5.6: configuration lives in `/etc/php/5.6`, not `/etc/php5`, and sessions in
  `/var/lib/php/sessions`. `/etc/php_config` works as before, but scripts in
  `/startup.d` that reference `/etc/php5` need updating.
- 5.6 keeps everything the old image had: mcrypt, bz2, dba, the legacy `mysql_*`
  functions, mod_ssl, and the PEAR libraries XML_Parser, XML_RPC and XML_DTD
  (from pear.php.net, since the distribution no longer ships them). PEAR and DB
  are newer versions.
- The Sury source stays in the image. In derived images, install packages with
  the version in the name (`php7.4-xdebug`), not `php-xdebug`: unversioned names
  point to the newest PHP at Sury and would pull in PHP 8.x. The build fails if
  a second PHP version shows up in `/etc/php`.
- New fixes reach the image only through a rebuild:
  `NO_CACHE=1 ./build.sh 7.4 7.4-mongodb1.18 5.6`.
- `:5` is now the same image as `5.6`. It used to be a separate PHP 5.6 build on
  Debian 8 (jessie).

### mongodb

Available in every image except 5.3 and 5.2. The `ext-mongodb` driver requires
PHP ≥ 5.5, so it cannot be installed there (the legacy `mongo` extension is an
option, but it has a different API).

| PHP | mongodb version | reason |
|-----|-----------------|--------|
| 8.5 / 8.4 / 8.2 / 8.1 | 2.5.2 | requires PHP 8.1+ |
| 7.4 | 1.20.1 | requires PHP 7.4+ |
| 7.4 (`:7.4-mongodb1.18`) | 1.18.0 | for applications that need 1.18; separate `Dockerfile.php7.4-mongodb1.18` |
| 7.2 | 1.11.1 | requires PHP 7.1+ |
| 7.0 | 1.9.2 | requires PHP 7.0+ |
| 5.6 / 5 | 1.7.4 | requires PHP 5.6+ |
| 5.5 | 1.5.5 | requires PHP 5.5+ |
| 5.4 | 1.2.9 | last release for PHP 5.4 |
| 5.3 / 5.2 | none | `ext-mongodb` requires PHP 5.5+ |

Versions are **pinned** in `build.sh`. An unpinned `pecl install mongodb`
installed the latest release, which silently failed to build on older PHP.

The PHP 5.5 and older images install mongodb and rar from the tarballs in `pecl/`,
not from the network. PEAR fails at random against the pecl.php.net REST API,
and a swallowed error used to produce images without mongodb. It also means the
build does not depend on old releases still being available on pecl.php.net.

`mongodb` is **required**: the build fails if the extension does not load after
installation. `rar` is optional, since it does not compile on PHP 8.x at all
([php-rar#17](https://github.com/cataphract/php-rar/issues/17)).
An `extension=` line is written only when the `.so` file actually exists, so an
image can never reference a missing extension.

### imap

Since PHP 8.4, `ext-imap` is no longer part of PHP (it moved to PECL), and the
c-client library it depends on has been unmaintained for years. Distributions
are dropping it.

| PHP | imap | source |
|-----|------|--------|
| 8.5 | yes | PECL `imap-1.0.3` on `libc-client2007e` from Ubuntu 26.04, with SSL and Kerberos |
| 8.4 | yes | PECL `imap-1.0.3` on `libc-client2007e` from **Debian bookworm**, with SSL and Kerberos |
| 7.4, 5.6 | yes | `php7.4-imap` / `php5.6-imap` package from Sury |
| 7.0 – 8.2 (except 7.4), legacy 5.x | yes | distribution package |

Debian trixie no longer ships c-client or `php-imap`, so the 8.4 image takes the
library alone from bookworm. An apt pin limits bookworm to `libc-client2007e`,
`libc-client2007e-dev` and `mlock`, and the bookworm source is removed after
installation. This works as long as bookworm is on `deb.debian.org` (LTS until
June 2028); after that, the URL has to change to `archive.debian.org`.

`ext-imap` is not available through PIE (Packagist), and PIE would still need
c-client to build it, so it does not solve the problem. The `imap` column in
`build.sh` controls the source (`apt` / `pecl` / `none`).

### Archival images

The PHP 5.5 and older images build from `archive.debian.org` and from the
third-party `sstrigler/squeeze` image. Run `docker save` on the finished images
and keep the archives: if any of these sources disappears, the images can never
be rebuilt.

---

## Derived images

`php8.5-node/Dockerfile` builds `narel/php:8.5` plus Node.js 24 (NodeSource),
yarn 1.x and wkhtmltopdf. It is built manually, not by `build.sh`:

```sh
docker build -t php-node:8.5 php8.5-node/
```

---

## License

Released under the [MIT License](LICENSE). PHP, Apache and the bundled
third-party packages keep their own licenses.
