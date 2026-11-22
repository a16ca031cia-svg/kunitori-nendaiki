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
