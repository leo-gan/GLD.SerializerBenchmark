/**
 * Languages sidebar: compact rows "C# · Dashboard".
 * - Language name → Overview URL
 * - Dashboard → /dashboard/?lang=<catalog-id>
 * - Flat sibling <a> elements (not Material nested-toggle targets)
 *
 * Why the name was unclickable before: Material treats the first
 * `.md-nav__link` under `.md-nav__item--nested` as the expand/collapse
 * control and intercepts its click.
 */
(function () {
  const DOCS_DIR_TO_LANG = {
    "c-sharp": "csharp",
    c: "c",
    cpp: "cpp",
    go: "go",
    java: "java",
    javascript: "javascript",
    python: "python",
    rust: "rust",
    swift: "swift",
  };

  function catalogIdFromOverviewHref(href) {
    // Resolve first: Material emits href="./" for the *current* Overview
    // (verified: site/c-sharp/index.html C# item is "./"; on /python/ the
    // same item is "../c-sharp/"). Splitting "./" would yield lang=".".
    const url = new URL(href || "./", window.location.href);
    const folder = url.pathname.replace(/\/+$/, "").split("/").pop();
    return DOCS_DIR_TO_LANG[folder] || folder;
  }

  function linkLabel(a) {
    if (!a) return "";
    const ellipsis = a.querySelector(".md-ellipsis");
    return (ellipsis ? ellipsis.textContent : a.textContent).trim();
  }

  function pageAnchor(item) {
    // Prefer a direct page link; skip TOC secondary nav links.
    for (const a of item.querySelectorAll("a.md-nav__link")) {
      if (a.closest(".md-nav--secondary")) continue;
      if (
        a.classList.contains("lang-nav-name") ||
        a.classList.contains("lang-nav-dash-link")
      ) {
        continue;
      }
      return a;
    }
    return null;
  }

  function ensureEl(li, selector, create) {
    let el = li.querySelector(`:scope > ${selector}`);
    if (!el) {
      el = create();
      li.appendChild(el);
    }
    return el;
  }

  function compactLanguageNav() {
    const root = document.querySelector(".md-sidebar--primary");
    if (!root) return;

    root
      .querySelectorAll(
        ".md-nav__item--section.md-nav__item--nested, .md-nav__item.lang-nav-row"
      )
      .forEach((li) => {
        // Prefer original nested list (hidden source) when re-running.
        const sourceNav =
          li.querySelector(":scope > .md-nav.lang-nav-source") ||
          li.querySelector(":scope > .md-nav");
        if (!sourceNav) return;

        const ul = sourceNav.querySelector(":scope > .md-nav__list");
        if (!ul) return;
        const items = Array.from(ul.children).filter(
          (el) => el.classList && el.classList.contains("md-nav__item")
        );
        if (items.length < 1) return;

        let overviewA = null;
        let overviewActive = false;

        items.forEach((item) => {
          const a = pageAnchor(item);
          const label = linkLabel(a);
          if (label === "Overview") {
            overviewA = a;
            overviewActive =
              !!(a && a.classList.contains("md-nav__link--active")) ||
              item.classList.contains("md-nav__item--active");
          }
        });
        // One-child nest: the only child is Overview.
        if (!overviewA && items.length === 1) {
          overviewA = pageAnchor(items[0]);
          overviewActive =
            !!(overviewA && overviewA.classList.contains("md-nav__link--active")) ||
            items[0].classList.contains("md-nav__item--active");
        }
        // Leftover Results sibling during a mixed tree: ignore it.

        if (!overviewA) return;

        const oldLabel = li.querySelector(":scope > label.md-nav__link");
        let name = "Language";
        const prior = li.querySelector(":scope > a.lang-nav-name .md-ellipsis, :scope > a.lang-nav-name .lang-nav-label");
        if (prior && prior.textContent.trim()) {
          name = prior.textContent.trim();
        } else if (oldLabel) {
          const ell = oldLabel.querySelector(".md-ellipsis");
          name = (ell ? ell.textContent : oldLabel.textContent).trim();
        }

        li.classList.add("lang-nav-row");
        // Stop Material treating this row as a collapsible nested section.
        li.classList.remove("md-nav__item--nested", "md-nav__item--section");

        const toggle = li.querySelector(":scope > .md-nav__toggle");
        if (toggle) {
          toggle.checked = true;
          toggle.disabled = true;
          toggle.hidden = true;
        }

        sourceNav.classList.add("lang-nav-source");
        sourceNav.setAttribute("aria-hidden", "true");
        sourceNav.hidden = true;
        if (oldLabel) {
          oldLabel.hidden = true;
          oldLabel.setAttribute("aria-hidden", "true");
        }

        // Drop a leftover Results sibling from a previous JS version.
        const leftoverResults = li.querySelector(":scope > a.lang-nav-results-link");
        if (leftoverResults) leftoverResults.remove();

        // Plain anchors — do NOT use md-nav__link (Material intercepts those
        // on nested items as the expand control).
        const nameLink = ensureEl(li, "a.lang-nav-name", () => {
          const a = document.createElement("a");
          a.className = "lang-nav-name";
          const span = document.createElement("span");
          span.className = "lang-nav-label";
          a.appendChild(span);
          return a;
        });
        const sep = ensureEl(li, "span.lang-nav-sep", () => {
          const s = document.createElement("span");
          s.className = "lang-nav-sep";
          s.setAttribute("aria-hidden", "true");
          s.textContent = "·";
          return s;
        });
        const dashLink = ensureEl(li, "a.lang-nav-dash-link", () => {
          const a = document.createElement("a");
          a.className = "lang-nav-dash-link";
          const span = document.createElement("span");
          span.className = "lang-nav-label";
          a.appendChild(span);
          return a;
        });

        // Stable visual order
        li.appendChild(nameLink);
        li.appendChild(sep);
        li.appendChild(dashLink);

        nameLink.href = overviewA.getAttribute("href") || overviewA.href;
        nameLink.title = `${name} overview`;
        const nameSpan = nameLink.querySelector(".lang-nav-label");
        if (nameSpan) nameSpan.textContent = name;
        nameLink.classList.toggle("lang-nav-active", overviewActive);

        const dashUrl = new URL("../dashboard/", window.location.href);
        dashUrl.searchParams.set(
          "lang",
          catalogIdFromOverviewHref(overviewA.getAttribute("href"))
        );
        dashLink.href = dashUrl.href;
        dashLink.title = `${name} Dashboard`;
        const dashSpan = dashLink.querySelector(".lang-nav-label");
        if (dashSpan) dashSpan.textContent = "Dashboard";
        // Deep link, not an in-section current page — never mark active.
        dashLink.classList.remove("lang-nav-active");
      });
  }

  if (typeof document$ !== "undefined" && document$.subscribe) {
    document$.subscribe(compactLanguageNav);
  } else {
    document.addEventListener("DOMContentLoaded", compactLanguageNav);
    window.addEventListener("load", compactLanguageNav);
  }
})();
