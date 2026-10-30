PORTNAME=	orca-ade
DISTVERSIONPREFIX=	v
DISTVERSION=	1.4.244
CATEGORIES=	editors devel

MAINTAINER=	christian@FreeBSD.org
COMMENT=	Next-gen Agent Development Environment (ADE) for AI coding agents
WWW=		https://github.com/stablyai/orca

LICENSE=	MIT
LICENSE_FILE=	${WRKSRC}/LICENSE

ONLY_FOR_ARCHS=	amd64

DISTFILES=	${PORTNAME}-node-modules-${DISTVERSION}.tar.xz

BUILD_DEPENDS=	electron${ELECTRON_VER_MAJOR}:devel/electron${ELECTRON_VER_MAJOR}
RUN_DEPENDS=	electron${ELECTRON_VER_MAJOR}:devel/electron${ELECTRON_VER_MAJOR} \
		git:devel/git \
		${LOCALBASE}/lib/libwayland-client.so:graphics/wayland

USES=		desktop-file-utils gmake nodejs:build pkgconfig python:build

USE_GITHUB=	yes
GH_ACCOUNT=	stablyai
GH_PROJECT=	orca

ELECTRON_VER_MAJOR?=	42
ELECTRON_VER=		42.11.10
COMMIT_HASH=		b8ec5c8d170bcb9988e65de547a3a4e98b2885a9

SUB_FILES=	orca-ade orca-ade.desktop
SUB_LIST=	ELECTRON_VER_MAJOR=${ELECTRON_VER_MAJOR}

PLIST_SUB=	PORTNAME=${PORTNAME}

post-extract:
	@if [ -d ${WRKDIR}/node_modules ]; then \
		${MV} ${WRKDIR}/node_modules ${WRKSRC}/; \
	fi

post-patch:
	@printf '%s\n' 'export function resolveBuildSourceCommit() { return "${COMMIT_HASH}"; }' > \
		${WRKSRC}/config/scripts/build-source-commit.mjs
	@node -e 'const fs = require("fs"); const p = "${WRKSRC}/src/main/window/clipboard-text-publisher.ts"; let s = fs.readFileSync(p, "utf8"); s = s.replace("const source = app.isPackaged", "const source = process.env.ORCA_WAYLAND_CLIPBOARD || app.isPackaged"); fs.writeFileSync(p, s);'

do-build:
	@${ECHO_MSG} "===> Compilando orca-wayland-clipboard"
	@${MKDIR} ${WRKSRC}/native/wayland-clipboard/.build/x64
	${CC} ${CFLAGS} -I${LOCALBASE}/include -L${LOCALBASE}/lib -fPIE -pie \
		${WRKSRC}/native/wayland-clipboard/wayland-clipboard.c \
		${WRKSRC}/native/wayland-clipboard/x11-clipboard-publisher.c \
		-o ${WRKSRC}/native/wayland-clipboard/.build/x64/orca-wayland-clipboard
	@${ECHO_MSG} "===> Recompilando modulos nativos Node para Electron ${ELECTRON_VER}"
	cd ${WRKSRC}/node_modules/node-pty && \
		${SETENV} ${MAKE_ENV} PYTHON=${PYTHON_CMD} \
		npm_config_runtime=electron \
		npm_config_target=${ELECTRON_VER} \
		npm_config_nodedir=${LOCALBASE}/share/electron${ELECTRON_VER_MAJOR}/node_headers \
		node-gyp rebuild
	cd ${WRKSRC}/node_modules/@parcel/watcher && \
		${SETENV} ${MAKE_ENV} PYTHON=${PYTHON_CMD} \
		npm_config_runtime=electron \
		npm_config_target=${ELECTRON_VER} \
		npm_config_nodedir=${LOCALBASE}/share/electron${ELECTRON_VER_MAJOR}/node_headers \
		node-gyp rebuild
	@${ECHO_MSG} "===> Compilando pacotes workspace"
	cd ${WRKSRC}/src/packages/process-host && \
		./node_modules/.bin/tsx --conditions=orca-source scripts/build-dist.mjs
	@${ECHO_MSG} "===> Transpilando bundle Electron (out/)"
	cd ${WRKSRC} && ${SETENV} ${MAKE_ENV} \
		ELECTRON_SKIP_BINARY_DOWNLOAD=1 \
		PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
		./node_modules/.bin/electron-vite build
	@${ECHO_MSG} "===> Preparando conteudo para app.asar"
	node ${FILESDIR}/prepare-asar-dir.mjs ${WRKSRC}
	@${ECHO_MSG} "===> Empacotando app.asar"
	asar pack --unpack-dir "{node_modules/node-pty,node_modules/@parcel/watcher,resources/bin}" \
		${WRKSRC}/dist-asar ${WRKSRC}/app.asar

do-install:
	@${MKDIR} ${STAGEDIR}${PREFIX}/bin
	@${MKDIR} ${STAGEDIR}${PREFIX}/share/applications
	@${MKDIR} ${STAGEDIR}${PREFIX}/share/pixmaps
	@${MKDIR} ${STAGEDIR}${DATADIR}/bin
	${INSTALL_SCRIPT} ${WRKDIR}/orca-ade ${STAGEDIR}${PREFIX}/bin
	${INSTALL_DATA} ${WRKDIR}/orca-ade.desktop ${STAGEDIR}${PREFIX}/share/applications
	${INSTALL_DATA} ${WRKSRC}/resources/icon.png ${STAGEDIR}${PREFIX}/share/pixmaps/orca-ade.png
	${INSTALL_PROGRAM} ${WRKSRC}/native/wayland-clipboard/.build/x64/orca-wayland-clipboard \
		${STAGEDIR}${DATADIR}/bin/
	${INSTALL_DATA} ${WRKSRC}/app.asar ${STAGEDIR}${DATADIR}/
	@if [ -d ${WRKSRC}/app.asar.unpacked ]; then \
		${CP} -a ${WRKSRC}/app.asar.unpacked ${STAGEDIR}${DATADIR}/; \
	fi

.include <bsd.port.mk>
