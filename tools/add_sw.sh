#!/bin/sh
# 書き出した build/web に「一度読み込んだ大きなファイルをブラウザに保存して使い回す」仕組みを足す
#  - index.html：ファイルの指紋（ハッシュ）の一覧を持ち、起動の前にブラウザの保存領域（Cache Storage）へ書く。
#    サービスワーカーがまだ無い初回だけ、働き始めるのを最大3秒待つ。起動の後、まだ保存していないファイルを裏で保存し、古い版の保存を消す
#  - sw.js：ページが書いた一覧の指紋で保存を探し、あればそれを返す（ネットワークを使わない）。
#    無ければネットワークから受け取りながらすぐ返し、保存は裏で行う（待たせない＝新しい版への切り替えも止めない）
# 公開をくり返しても、中身の変わっていないファイル（エンジン本体など）は取り直さない
cd "$(dirname "$0")/../build/web" || exit 1
FILES="index.js index.wasm index.pck index.png index.icon.png jpmap0.bin jpmap1.bin jpmap2.bin jpmap3.bin bgm_peace.ogg bgm_war.ogg index.audio.worklet.js index.audio.position.worklet.js"
MAN=""
for f in $FILES; do
	[ -f "$f" ] || continue
	h=$(sha1sum "$f" | cut -c1-16)
	MAN="$MAN\"$f\":\"$h\","
done
MAN="{${MAN%,}}"
cat > sw.js <<'EOF'
// 自動生成（tools/add_sw.sh）：大きなファイルを中身の指紋つきでブラウザに保存して使い回す
const STORE = "kunitori-files";
function plain(r) {
	const h = new Headers(r.headers);
	h.delete("content-encoding");
	h.delete("content-length");
	return new Response(r.body, { status: r.status, statusText: r.statusText, headers: h });
}
self.addEventListener("install", (e) => self.skipWaiting());
self.addEventListener("activate", (e) => e.waitUntil(self.clients.claim()));
self.addEventListener("fetch", (e) => {
	if (e.request.method !== "GET") return;
	const u = new URL(e.request.url);
	if (u.origin !== self.location.origin || u.searchParams.has("h")) return;
	const name = u.pathname.split("/").pop();
	if (!name || name === "sw.js" || name.endsWith(".html")) return;
	e.respondWith((async () => {
		const c = await caches.open(STORE);
		const mr = await c.match("kunitori-manifest");
		const man = mr ? await mr.json() : null;
		const h = man && man[name];
		if (!h) return fetch(e.request);
		const key = new URL(name + "?h=" + h, self.registration.scope).href;
		const hit = await c.match(key);
		if (hit) return plain(hit);
		const r = await fetch(key, { cache: "no-store" });
		if (!r.ok) return r;
		// 中身はブラウザが解凍済みなので、「圧縮してある」印と長さを外して渡す・保存する（付いたままだと取得側がもう一度解凍しようとして失敗する）
		const clean = plain(r);
		c.put(key, clean.clone()).catch(() => {});
		return clean;
	})());
});
EOF
# index.html：一覧を書き、必要なら初回だけサービスワーカーを待ってから起動する（まだ足していなければ足す）
if ! grep -q "kunitoriPrep" index.html; then
	perl -0pi -e 's/(const engine = new Engine\(GODOT_CONFIG\);\n)/$1\n\/\/ 大きなファイルをブラウザに保存して使い回す（tools\/add_sw.sh）\nlet KUNITORI_FILES = __KMAN__;\nasync function kunitoriPrep() {\n\ttry {\n\t\tif (!("caches" in window) || !("serviceWorker" in navigator) || location.protocol === "file:") return;\n\t\tconst c = await caches.open("kunitori-files");\n\t\t\/\/ 一覧は files.json から毎回取り直す（index.html はブラウザに最大10分残るので、公開の直後でも新しい版を読むように）\n\t\ttry { const fr = await fetch("files.json", { cache: "no-store" }); if (fr.ok) KUNITORI_FILES = await fr.json(); } catch (e) {}\n\t\tawait c.put("kunitori-manifest", new Response(JSON.stringify(KUNITORI_FILES)));\n\t\tlet first = !navigator.serviceWorker.controller;\n\t\tfor (const r of await navigator.serviceWorker.getRegistrations()) { const w = r.active || r.waiting || r.installing; if (w && w.scriptURL.indexOf("sw.js?v=") >= 0) { await r.unregister(); first = true; } }\n\t\tconst reg = navigator.serviceWorker.register("sw.js").catch(() => null);\n\t\tif (first) await Promise.race([new Promise((r) => navigator.serviceWorker.addEventListener("controllerchange", r, { once: true })), new Promise((r) => setTimeout(r, 3000))]);\n\t} catch (e) {}\n}\n\/\/ 起動の後：まだ保存していないファイルを裏で保存し、古い版の保存を消す\nasync function kunitoriFill() {\n\ttry {\n\t\tif (!("caches" in window)) return;\n\t\tawait new Promise((r) => setTimeout(r, 15000));\n\t\tconst c = await caches.open("kunitori-files");\n\t\tconst want = {};\n\t\tfor (const [n, h] of Object.entries(KUNITORI_FILES)) want[new URL(n + "?h=" + h, location.href).href] = true;\n\t\tfor (const req of await c.keys()) if (!want[req.url] && !req.url.endsWith("kunitori-manifest")) await c.delete(req);\n\t\tfor (const k of Object.keys(want)) {\n\t\t\tif (await c.match(k)) continue;\n\t\t\tconst r = await fetch(k, { cache: "no-store" });\n\t\t\tif (r.ok) await c.put(k, new Response(await r.blob(), { headers: { "content-type": r.headers.get("content-type") || "application\/octet-stream" } }));\n\t\t}\n\t} catch (e) {}\n}\n/' index.html
	perl -0pi -e 's/\t\tsetStatusMode\(\x27progress\x27\);\n\t\tengine\.startGame\(\{/\t\tsetStatusMode(\x27progress\x27);\n\t\tkunitoriPrep().then(() => engine.startGame({/; s/(\t\t\tsetStatusMode\(\x27hidden\x27\);\n)(\t\t\}, displayFailureNotice)\);/$1\t\t\tkunitoriFill();\n$2));/' index.html
fi
perl -0pi -e 's/let KUNITORI_FILES = [^;]*;/let KUNITORI_FILES = '"$MAN"';/' index.html
printf "%s" "$MAN" > files.json   # 起動の時に毎回取り直す一覧（index.html が古いままでも新しい版を読むため）
grep -c "kunitoriPrep\|kunitoriFill" index.html
echo "sw.js と一覧を作りました"
