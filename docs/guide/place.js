// The guide's and the manual's sense of place (meeting 2026-10-28-2214, § 5):
// the contents show the chapter on screen, and the reader's place is kept
// in the browser's own storage, one per page, so the page opens where they
// left off. When storage is blocked (a private window, a strict browser),
// the page simply opens at the top.
(function () {
  var key = "agendum-place:" + location.pathname;
  var links = {};
  document.querySelectorAll("nav.toc a[href^='#']").forEach(function (a) {
    links[a.getAttribute("href").slice(1)] = a;
  });
  var sections = Array.prototype.filter.call(
    document.querySelectorAll("main section[id]"),
    function (s) { return links[s.id]; }
  );

  // the current chapter: the last one whose top has passed a third of the
  // way down the window
  function current() {
    var line = window.innerHeight / 3, here = sections[0];
    sections.forEach(function (s) {
      if (s.getBoundingClientRect().top <= line) here = s;
    });
    return here;
  }

  var shown = null;
  function mark() {
    var here = current();
    if (!here || here === shown) return;
    if (shown) links[shown.id].removeAttribute("aria-current");
    links[here.id].setAttribute("aria-current", "true");
    follow(links[here.id]);
    shown = here;
  }

  // keeps the highlighted chapter in view inside a sidebar that scrolls, and
  // never moves the page itself (on a narrow window the contents are on top)
  var nav = document.querySelector("nav.toc");
  function follow(a) {
    if (!nav || nav.scrollHeight <= nav.clientHeight) return;
    // the sidebar is sticky, so positioned: a link's offsetTop is inside it
    var top = a.offsetTop, bottom = top + a.offsetHeight;
    if (top < nav.scrollTop) nav.scrollTop = top;
    else if (bottom > nav.scrollTop + nav.clientHeight) nav.scrollTop = bottom - nav.clientHeight;
  }

  var saving = null;
  function save() {
    clearTimeout(saving);
    saving = setTimeout(function () {
      try { localStorage.setItem(key, String(Math.round(window.scrollY))); } catch (e) {}
    }, 300);
  }

  // back where you left off, unless the address names a chapter
  if (!location.hash) {
    var y = null;
    try { y = localStorage.getItem(key); } catch (e) {}
    if (y !== null) window.scrollTo(0, parseInt(y, 10) || 0);
  }

  window.addEventListener("scroll", function () { mark(); save(); }, { passive: true });
  window.addEventListener("resize", mark);
  mark();
})();
