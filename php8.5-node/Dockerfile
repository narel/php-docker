# ---------------------------------------------------------------------------
# narel/php:8.5 + Node.js, yarn and wkhtmltopdf.
#
# Built manually, not part of ./build.sh:
#   docker build -t php-node:8.5 php8.5-node/
#
# The mongodb PHP extension is already in the base image - this only checks
# that it loads.
# ---------------------------------------------------------------------------
FROM narel/php:8.5

ARG NODE_MAJOR=24
# yarn classic (1.x). Projects on Yarn 2+ still work: yarn 1 hands the call
# over to the version set in .yarnrc.yml (yarnPath).
ARG YARN_VER=1.22.22
# wkhtmltopdf is not in Ubuntu 26.04, and the project is archived. The jammy
# package works on 26.04 and has "patched qt" (headers, footers, TOC).
ARG WKHTMLTOX_URL=https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb
ARG WKHTMLTOX_SHA256=4f723b2691ad8638a9df960e0421d346d7315083e3583a334f33362280ddba15

RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    install -d /etc/apt/keyrings; \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        -o /etc/apt/keyrings/nodesource.asc; \
    printf '%s\n' 'Types: deb' "URIs: https://deb.nodesource.com/node_${NODE_MAJOR}.x" \
        'Suites: nodistro' 'Components: main' \
        'Signed-By: /etc/apt/keyrings/nodesource.asc' \
        > /etc/apt/sources.list.d/nodesource.sources; \
    curl -fsSL "${WKHTMLTOX_URL}" -o /tmp/wkhtmltox.deb; \
    echo "${WKHTMLTOX_SHA256}  /tmp/wkhtmltox.deb" | sha256sum -c -; \
    apt-get update; \
    apt-get install --no-install-recommends -y \
        nodejs /tmp/wkhtmltox.deb \
        # carried over from the old image - most likely for headless Chrome (puppeteer)
        libnss3 libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 libxkbcommon0 \
        libxcomposite1 libxdamage1 libxrandr2 libgbm1 libpango-1.0-0 libcairo2 \
        libsoundio2; \
    npm install -g "yarn@${YARN_VER}"; \
    npm cache clean --force; \
    a2enmod headers; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.npm; \
    node --version; \
    yarn --version; \
    wkhtmltopdf --version; \
    php -m | grep -qix mongodb \
        || { echo "ERROR: extension mongodb is not loaded"; exit 1; }; \
    apache2ctl -t
