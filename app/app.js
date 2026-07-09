/* OpenWiki Hub — fetches /api/wikis (manifest) and renders markdown files. */

const $ = (sel) => document.querySelector(sel);

let manifest = null;
let activeWiki = null;
let activeFile = null;

async function loadManifest() {
  const res = await fetch("/wikis.json");
  if (!res.ok) throw new Error(`manifest fetch failed (${res.status}). ¿Corriste 'owhu' ?`);
  manifest = await res.json();
  renderSidebar();
}

function renderSidebar() {
  const nav = $("#wikis");
  const stats = $("#stats");
  nav.innerHTML = "";

  const wikiCount = manifest.wikis.length;
  const fileCount = manifest.wikis.reduce(
    (n, w) => n + w.files.length,
    0,
  );
  stats.textContent = `${wikiCount} project${wikiCount === 1 ? "" : "s"} · ${fileCount} file${fileCount === 1 ? "" : "s"}`;

  if (wikiCount === 0) {
    nav.innerHTML = `<div style="padding:14px 18px;color:var(--fg-dim);font-size:12px;">
      No wikis yet.<br/><br/>
      Run <code style="background:var(--code-bg);padding:2px 6px;border-radius:4px;">owhu</code> in your terminal.
    </div>`;
    return;
  }

  for (const wiki of manifest.wikis) {
    const group = document.createElement("div");
    group.className = "wiki-group";

    const groupName = document.createElement("div");
    groupName.className = "wiki-group-name";
    groupName.textContent = wiki.name;
    group.appendChild(groupName);

    const link = document.createElement("a");
    link.className = "wiki";
    link.innerHTML = `${wiki.label}<span class="meta">${wiki.files.length} file${wiki.files.length === 1 ? "" : "s"} · ${wiki.updatedAt}</span>`;
    link.onclick = (e) => {
      e.preventDefault();
      openWiki(wiki, wiki.files[0]);
    };
    group.appendChild(link);

    const fileList = document.createElement("div");
    fileList.className = "wiki-files";
    fileList.style.display = "none";
    for (const file of wiki.files) {
      const f = document.createElement("a");
      f.className = "wiki-file";
      f.textContent = file.label;
      f.dataset.path = file.path;
      f.onclick = (e) => {
        e.preventDefault();
        openWiki(wiki, file);
      };
      fileList.appendChild(f);
    }
    link.after(fileList);
    link.addEventListener("dblclick", () => {
      fileList.style.display =
        fileList.style.display === "none" ? "block" : "none";
    });
    // also toggle on click for simpler UX
    link._fileList = fileList;

    nav.appendChild(group);
  }

  $("#last-build").textContent = `Built ${new Date(manifest.builtAt).toLocaleString()}`;
}

async function openWiki(wiki, file) {
  if (!file) return;

  // sidebar highlight
  document.querySelectorAll(".wiki").forEach((el) => el.classList.remove("active"));
  document.querySelectorAll(".wiki-file").forEach((el) => el.classList.remove("active"));
  const allLinks = document.querySelectorAll(".wiki");
  const idx = manifest.wikis.findIndex((w) => w.name === wiki.name);
  if (idx >= 0 && allLinks[idx]) {
    allLinks[idx].classList.add("active");
    allLinks[idx]._fileList.style.display = "block";
  }
  document.querySelectorAll(".wiki-file").forEach((el) => {
    if (el.dataset.path === file.path) el.classList.add("active");
  });

  activeWiki = wiki;
  activeFile = file;

  const content = $("#content");
  content.innerHTML = `<div class="placeholder">Loading…</div>`;

  try {
    const res = await fetch(`/${file.path}`);
    if (!res.ok) throw new Error(`fetch ${file.path}: ${res.status}`);
    const md = await res.text();
    content.innerHTML = `
      <div class="breadcrumb">
        <a href="#" onclick="event.preventDefault()">${wiki.label}</a>
        &nbsp;/&nbsp; ${file.label}
      </div>
      ${marked.parse(md)}
    `;
    await renderMermaidBlocks(content);
  } catch (err) {
    content.innerHTML = `<div class="placeholder">Error: ${err.message}</div>`;
  }
}

async function renderMermaidBlocks(root) {
  if (typeof mermaid === "undefined") {
    await new Promise((r) => setTimeout(r, 200));
    if (typeof mermaid === "undefined") {
      console.warn("mermaid.js not loaded; diagrams will not render");
      return;
    }
  }
  if (!window._mermaidInit) {
    mermaid.initialize({
      startOnLoad: false,
      theme: "dark",
      securityLevel: "loose",
      themeVariables: {
        background: "#161922",
        primaryColor: "#1d2130",
        primaryTextColor: "#e4e6eb",
        primaryBorderColor: "#2a2f3d",
        lineColor: "#8b91a3",
        secondaryColor: "#1d2130",
        tertiaryColor: "#1d2130",
      },
    });
    window._mermaidInit = true;
  }
  const blocks = root.querySelectorAll("pre code.language-mermaid");
  for (const block of blocks) {
    const source = block.textContent;
    const id = "mermaid-" + Math.random().toString(36).slice(2, 10);
    try {
      const { svg } = await mermaid.render(id, source);
      const wrapper = document.createElement("div");
      wrapper.className = "mermaid-diagram";
      wrapper.innerHTML = svg;
      block.parentElement.replaceWith(wrapper);
    } catch (err) {
      const errBox = document.createElement("div");
      errBox.className = "mermaid-error";
      errBox.textContent = `Mermaid error: ${err.message || err}`;
      block.parentElement.replaceWith(errBox);
    }
  }
}

document.addEventListener("DOMContentLoaded", async () => {
  try {
    await loadManifest();
  } catch (e) {
    $("#wikis").innerHTML = `<div style="padding:18px;color:#f87171;font-size:12px;">
      ${e.message}
    </div>`;
  }
});