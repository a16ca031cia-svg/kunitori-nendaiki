#!/bin/sh
# 書き出した build/web に「一度読み込んだ大きなファイルをブラウザに保存して使い回す」仕組みを足す
#  - sw.js（サービスワーカー）：エンジン本体・ゲームの中身・地図・曲を、中身の指紋（ハッシュ）つきで保存。
#    指紋が同じなら保存した物を返し、ネットワークを使わない（公開をくり返しても、変わっていないエンジン本体は取り直さない）
#  - index.html：エンジンを起動する前に、最新の sw.js が働き始めるのを待つ（最大3秒。だめなら今までどおり）
cd "$(dirname "$0")/../build/web" || exit 1
FILES="index.js index.wasm index.pck index.png index.icon.png jpmap0.bin jpmap1.bin jpmap2.bin jpmap3.bin bgm_peace.ogg bgm_war.ogg index.audio.worklet.js index.audio.position.worklet.js"
MAN=""
for f in $FILES; do
	[ -f "$f" ] || continue
	h=$(sha1sum "$f" | cut -c1-16)
	MAN="$MAN\"$f\":\"$h\","
done
VER=$(printf '%s' "$MAN" | sha1sum | cut -c1-12)
cat > sw.js <<EOF
// 自動生成（tools/add_sw.sh）：大きなファイルを中身の指紋つきでブラウザに保存して使い回す
const VER = "$VER";
const FILES = {${MAN%,}};
const STORE = "kunitori-files";
self.addEventListener("install", (e) => self.skipWaiting());
self.addEventListener("activate", (e) => e.waitUntil((async () => {
	await self.clients.claim();
	// いまの指紋に合わない古い保存は消す
	const c = await caches.open(STORE);
	for (const req of await c.keys()) {
		const u = new URL(req.url);
		const name = u.pathname.split("/").pop();
		if (FILES[name] !== u.searchParams.get("h")) await c.delete(req);
	}
})()));
self.addEventListener("fetch", (e) => {
	if (e.request.method !== "GET") return;
	const u = new URL(e.request.url);
	if (u.origin !== self.location.origin) return;
	const name = u.pathname.split("/").pop();
	const h = FILES[name];
	if (!h) return;
	e.respondWith((async () => {
		const c = await caches.open(STORE);
		const key = new URL(name + "?h=" + h, self.registration.scope).href;
		const hit = await c.match(key);
		if (hit) return hit;
		// 指紋つきの URL で取りに行く（ブラウザの古い一時保存を使わないように）
		const r = await fetch(key, { cache: "no-store" });
		if (r.ok) await c.put(key, r.clone());
		return r;
	})());
});
EOF
# index.html：エンジンの起動の前に sw.js を待つ（すでに足してあれば何もしない）
if ! grep -q "kunitoriSwReady" index.html; then
	perl -0pi -e 's/(const engine = new Engine\(GODOT_CONFIG\);\n)/$1\n\/\/ 大きなファイルをブラウザに保存して使い回す（tools\/add_sw.sh）。最新の sw.js が働き始めるまで最大3秒待つ\nfunction kunitoriSwReady() {\n\tif (!("serviceWorker" in navigator) || location.protocol === "file:") return Promise.resolve();\n\treturn new Promise((resolve) => {\n\t\tconst done = () => resolve();\n\t\tsetTimeout(done, 3000);\n\t\tconst ver = "__SWVER__";\n\t\tconst cur = navigator.serviceWorker.controller;\n\t\tif (cur && cur.scriptURL.endsWith("sw.js?v=" + ver)) { done(); return; }\n\t\tnavigator.serviceWorker.addEventListener("controllerchange", done, { once: true });\n\t\tnavigator.serviceWorker.register("sw.js?v=" + ver).catch(done);\n\t});\n}\n/' index.html
	perl -0pi -e 's/\t\tsetStatusMode\(\x27progress\x27\);\n\t\tengine\.startGame\(\{/\t\tsetStatusMode(\x27progress\x27);\n\t\tkunitoriSwReady().then(() => engine.startGame({/; s/(\t\t\tsetStatusMode\(\x27hidden\x27\);\n\t\t\}, displayFailureNotice)\);/$1));/' index.html
fi
perl -pi -e 's/sw\.js\?v=[0-9a-f_A-Z]+/sw.js?v='"$VER"'/g; s/const ver = "[^"]*";/const ver = "'"$VER"'";/' index.html
grep -c "kunitoriSwReady" index.html
echo "sw.js を作りました（版 $VER）"
