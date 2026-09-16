(() => {
  const nav = document.getElementById("nav");
  const burger = document.getElementById("burger");
  const drawer = document.getElementById("drawer");
  const hero = document.querySelector(".hero");

  const onScrollNav = () => {
    if (!nav) return;
    nav.classList.toggle("is-solid", window.scrollY > 24);
  };

  window.addEventListener("scroll", onScrollNav, { passive: true });
  onScrollNav();

  if (hero) {
    requestAnimationFrame(() => hero.classList.add("is-ready"));
  }

  if (burger && drawer) {
    burger.addEventListener("click", () => {
      const open = drawer.hasAttribute("hidden");
      if (open) {
        drawer.removeAttribute("hidden");
        burger.setAttribute("aria-expanded", "true");
      } else {
        drawer.setAttribute("hidden", "");
        burger.setAttribute("aria-expanded", "false");
      }
    });

    drawer.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", () => {
        drawer.setAttribute("hidden", "");
        burger.setAttribute("aria-expanded", "false");
      });
    });
  }

  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const nodes = document.querySelectorAll(".reveal");

  if (reduceMotion) {
    nodes.forEach((el) => el.classList.add("is-in"));
    return;
  }

  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-in");
        io.unobserve(entry.target);
      });
    },
    {
      root: null,
      rootMargin: "0px 0px -8% 0px",
      threshold: 0.12,
    }
  );

  nodes.forEach((el) => io.observe(el));

  // Ligero parallax del fondo del hero (solo desktop / si no reduce motion)
  const bg = document.querySelector(".hero__bg");
  if (bg && window.matchMedia("(min-width: 800px)").matches) {
    let ticking = false;
    window.addEventListener(
      "scroll",
      () => {
        if (ticking) return;
        ticking = true;
        requestAnimationFrame(() => {
          const y = Math.min(window.scrollY, 600);
          bg.style.transform = `scale(1) translate3d(0, ${y * 0.18}px, 0)`;
          ticking = false;
        });
      },
      { passive: true }
    );
  }
})();
