/**
 * Languages sidebar: compact rows "Rust · Results".
 * - Language name → Overview URL
 * - Results → results page
 * - Flat sibling <a> elements (not Material nested-toggle targets)
 *
 * Why the name was unclickable before: Material treats the first
 * `.md-nav__link` under `.md-nav__item--nested` as the expand/collapse
 * control and intercepts its click. Results lived deeper and still worked.
 */
(function () {
  function linkLabel(a) {
    if (!a) return "";
    const ellipsis = a.querySelector(".md-ellipsis");
    return (ellipsis ? ellipsis.textContent : a.textContent).trim();
  }

  function directPageItems(li) {
    const ul = li.querySelector(":scope > .md-nav > .md-nav__list");
    if (!ul) return null;
    return Array.from(ul.children).filter(
      (el) => el.classList && el.classList.contains("md-nav__item")
    );
  }

  function pageAnchor(item) {
    // Prefer a direct page link; skip TOC secondary nav links.
    for (const a of item.querySelectorAll("a.md-nav__link")) {
      if (a.closest(".md-nav--secondary")) continue;
      if (
        a.classList.contains("lang-nav-name") ||
        a.classList.contains("lang-nav-results-link")
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
        if (items.length !== 2) return;

        let overviewA = null;
        let resultsA = null;
        let overviewActive = false;
        let resultsActive = false;

        items.forEach((item) => {
          const a = pageAnchor(item);
          const label = linkLabel(a);
          if (label === "Overview") {
            overviewA = a;
            overviewActive =
              !!(a && a.classList.contains("md-nav__link--active")) ||
              item.classList.contains("md-nav__item--active");
          } else if (label === "Results") {
            resultsA = a;
            resultsActive =
              !!(a && a.classList.contains("md-nav__link--active")) ||
              item.classList.contains("md-nav__item--active");
          }
        });

        if (!overviewA || !resultsA) return;

        const oldLabel = li.querySelector(":scope > label.md-nav__link");
        let name = "Language";
        const prior = li.querySelector(":scope > a.lang-nav-name .md-ellipsis");
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
        const resultsLink = ensureEl(li, "a.lang-nav-results-link", () => {
          const a = document.createElement("a");
          a.className = "lang-nav-results-link";
          const span = document.createElement("span");
          span.className = "lang-nav-label";
          a.appendChild(span);
          return a;
        });

        // Stable visual order
        li.appendChild(nameLink);
        li.appendChild(sep);
        li.appendChild(resultsLink);

        nameLink.href = overviewA.getAttribute("href") || overviewA.href;
        nameLink.title = `${name} overview`;
        const nameSpan = nameLink.querySelector(".lang-nav-label");
        if (nameSpan) nameSpan.textContent = name;
        nameLink.classList.toggle("lang-nav-active", overviewActive);

        resultsLink.href = resultsA.getAttribute("href") || resultsA.href;
        resultsLink.title = `${name} results`;
        const resSpan = resultsLink.querySelector(".lang-nav-label");
        if (resSpan) resSpan.textContent = "Results";
        resultsLink.classList.toggle("lang-nav-active", resultsActive);
      });
  }

  if (typeof document$ !== "undefined" && document$.subscribe) {
    document$.subscribe(compactLanguageNav);
  } else {
    document.addEventListener("DOMContentLoaded", compactLanguageNav);
    window.addEventListener("load", compactLanguageNav);
  }
})();
