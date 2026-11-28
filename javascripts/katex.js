/**
 * KaTeX auto-render hook compatible with MkDocs Material navigation.instant.
 */
(function () {
  function renderMath(root) {
    if (typeof renderMathInElement !== "function") return;
    renderMathInElement(root || document.body, {
      delimiters: [
        { left: "\\(", right: "\\)", display: false },
        { left: "\\[", right: "\\]", display: true },
        { left: "$$", right: "$$", display: true },
        { left: "$", right: "$", display: false },
      ],
      throwOnError: false,
    });
  }

  if (typeof document$ !== "undefined" && document$.subscribe) {
    document$.subscribe(function (doc) {
      renderMath(doc && doc.body ? doc.body : document.body);
    });
  } else {
    document.addEventListener("DOMContentLoaded", function () {
      renderMath(document.body);
    });
  }
})();
