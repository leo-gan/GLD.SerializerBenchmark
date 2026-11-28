/**
 * Languages sidebar: compact rows "C# · Dashboard".
 * - Language name → Overview URL
 * - Dashboard → <site-root>dashboard/?lang=<catalog-id>
 * - Flat sibling <a> elements (not Material nested-toggle targets)
 *
 * Works with MkDocs Material's `navigation.indexes` enabled (where a one-child
 * `- C: [Overview: c/index.md]` renders as `.md-nav__container > a.md-nav__link`
 * with an empty child list) as well as the legacy non-indexed nested list form.
 */
(function () {
  const DOCS_DIR_TO_LANG = {
    "c-sharp": "csharp",
    c: "c",
    cpp: "cpp",
    fortran: "fortran",
    go: "go",
    java: "java",
    javascript: "javascript",
    kotlin: "kotlin",
    mojo: "mojo",
    php: "php",
    python: "python",
    rust: "rust",
    swift: "swift",
    zig: "zig",
  };

  function folderFromHref(href) {
    const url = new URL(href || "./", window.location.href);
    return url.pathname.replace(/\/+$/, "").split("/").pop() || "";
  }

  function catalogIdFromOverviewHref(href) {
    const folder = folderFromHref(href);
    return Object.prototype.hasOwnProperty.call(DOCS_DIR_TO_LANG, folder)
      ? DOCS_DIR_TO_LANG[folder]
      : null;
  }

  function linkLabel(a) {
    if (!a) return "";
    const ellipsis = a.querySelector(".md-ellipsis");
    return (ellipsis ? ellipsis.textContent : a.textContent).trim();
  }

  function pageAnchor(item) {
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
        const sourceNav =
          li.querySelector(":scope > .md-nav.lang-nav-source") ||
          li.querySelector(":scope > .md-nav");
        const container = li.querySelector(":scope > .md-nav__container");
        const containerLink = container
          ? container.querySelector(":scope > a.md-nav__link")
          : null;

        let overviewA = null;
        let overviewActive = false;
        let name = "";

        if (sourceNav) {
          const ul = sourceNav.querySelector(":scope > .md-nav__list");
          const items = ul
            ? Array.from(ul.children).filter(
                (el) => el.classList && el.classList.contains("md-nav__item")
              )
            : [];

          if (items.length === 0 && containerLink) {
            // Material `navigation.indexes`: index page sits in `.md-nav__container`
            // and child list is empty. Only compact if href resolves to one of the
            // 14 registered language directories.
            if (!catalogIdFromOverviewHref(containerLink.getAttribute("href"))) {
              return;
            }
            overviewA = containerLink;
            overviewActive =
              containerLink.classList.contains("md-nav__link--active") ||
              li.classList.contains("md-nav__item--active");
            name = linkLabel(containerLink);
          } else if (items.length === 1) {
            const a = pageAnchor(items[0]);
            if (!a || !catalogIdFromOverviewHref(a.getAttribute("href"))) return;
            overviewA = a;
            overviewActive =
              a.classList.contains("md-nav__link--active") ||
              items[0].classList.contains("md-nav__item--active");
          } else {
            return;
          }
        } else {
          return;
        }

        if (!overviewA) return;
        const catalogId = catalogIdFromOverviewHref(overviewA.getAttribute("href"));
        if (!catalogId) return;

        const oldLabel = li.querySelector(":scope > label.md-nav__link");
        const prior = li.querySelector(
          ":scope > a.lang-nav-name .md-ellipsis, :scope > a.lang-nav-name .lang-nav-label"
        );
        if (prior && prior.textContent.trim()) {
          name = prior.textContent.trim();
        } else if (!name && oldLabel) {
          name = linkLabel(oldLabel);
        }
        if (!name) name = catalogId;

        li.classList.add("lang-nav-row");
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
        if (container) {
          container.classList.add("lang-nav-source");
          container.setAttribute("aria-hidden", "true");
          container.hidden = true;
        }
        if (oldLabel) {
          oldLabel.hidden = true;
          oldLabel.setAttribute("aria-hidden", "true");
        }

        const staleResultsLink = li.querySelector(":scope > a.lang-nav-results-link");
        if (staleResultsLink) staleResultsLink.remove();

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

        li.appendChild(nameLink);
        li.appendChild(sep);
        li.appendChild(dashLink);

        nameLink.href = overviewA.getAttribute("href") || overviewA.href;
        nameLink.title = `${name} overview`;
        const nameSpan = nameLink.querySelector(".lang-nav-label");
        if (nameSpan) nameSpan.textContent = name;
        nameLink.classList.toggle("lang-nav-active", overviewActive);

        const logo = document.querySelector("a.md-header__button.md-logo");
        const rootHref = (logo && logo.getAttribute("href")) || "./";
        const siteRoot = new URL(rootHref, window.location.href);
        if (!siteRoot.pathname.endsWith("/")) siteRoot.pathname += "/";
        const dashUrl = new URL("dashboard/", siteRoot);
        dashUrl.searchParams.set("lang", catalogId);
        dashLink.href = dashUrl.href;
        dashLink.title = `${name} Dashboard`;
        const dashSpan = dashLink.querySelector(".lang-nav-label");
        if (dashSpan) dashSpan.textContent = "Dashboard";
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
