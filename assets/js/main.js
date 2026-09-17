/* ============================================================================
   FERNANDO PATERSON — Portfolio · main.js
   GSAP + ScrollTrigger + Lenis (todo local, sin CDN).

   Cada bloque de comportamiento vive en su propia función y se registra al
   final del archivo. Si un módulo no encuentra su marcado, simplemente no
   hace nada: por eso el mismo script sirve para la home y para los cases.

   Todo degrada: sin JS el sitio se lee entero, sin GSAP se ve estático, y
   con "prefers-reduced-motion" no se anima nada.
   ========================================================================== */

(function () {
  'use strict';

  var raiz = document.documentElement;
  raiz.classList.add('js');

  /* ---------------------------------------------------------------- entorno */

  var sinMovimiento = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var punteroFino   = window.matchMedia('(hover: hover) and (pointer: fine)').matches;
  var hayGSAP       = typeof window.gsap !== 'undefined';
  var animar        = hayGSAP && !sinMovimiento;   // condición de casi todo

  var lenis = null;   // lo rellena scrollSuave()

  if (hayGSAP && typeof window.ScrollTrigger !== 'undefined') {
    gsap.registerPlugin(ScrollTrigger);
  }

  /* --------------------------------------------------------------- utilidades */

  function uno(selector, contexto) {
    return (contexto || document).querySelector(selector);
  }

  function todos(selector, contexto) {
    return Array.prototype.slice.call((contexto || document).querySelectorAll(selector));
  }

  /* La cabecera es fija y opaca: hay que descontarla o tapa el destino. */
  function altoCabecera() {
    var cabecera = uno('.site-head');
    return cabecera ? cabecera.offsetHeight : 0;
  }

  function irA(destino) {
    var el = typeof destino === 'string' ? uno(destino) : destino;
    if (!el) return;

    var margen = altoCabecera() + 12;

    if (lenis) {
      lenis.scrollTo(el, { offset: -margen });
    } else {
      window.scrollTo({
        top: el.getBoundingClientRect().top + window.pageYOffset - margen,
        behavior: sinMovimiento ? 'auto' : 'smooth'
      });
    }
  }

  /* Parte un texto en caracteres animables sin perderlo para lectores de pantalla. */
  function partirEnLetras(el) {
    var texto = el.textContent;
    el.setAttribute('aria-label', texto);
    el.textContent = '';
    texto.split('').forEach(function (caracter) {
      var span = document.createElement('span');
      span.className = 'char';
      span.textContent = caracter;
      span.setAttribute('aria-hidden', 'true');
      el.appendChild(span);
    });
    return todos('.char', el);
  }

  function refrescarScrollTrigger() {
    if (animar) ScrollTrigger.refresh();
  }

  /* ¿El elemento ya está a la vista (o a un pelo de estarlo) al arrancar?
     Lo que ya se ve no se anima: se muestra directamente. Así, al recargar
     a media página o al volver atrás, nada aparece en blanco esperando turno. */
  function yaALaVista(el) {
    return el.getBoundingClientRect().top < window.innerHeight * 1.05;
  }


  /* ======================================================================
     Scroll suave
     ====================================================================== */

  function scrollSuave() {
    if (sinMovimiento || typeof window.Lenis === 'undefined') return;

    lenis = new Lenis({ duration: 1.15, smoothWheel: true });
    lenis.on('scroll', function () {
      if (hayGSAP) ScrollTrigger.update();
    });

    if (hayGSAP) {
      // Un único reloj para GSAP y Lenis evita que se peleen por el rAF.
      gsap.ticker.add(function (tiempo) { lenis.raf(tiempo * 1000); });
      gsap.ticker.lagSmoothing(0);
    } else {
      (function bucle(t) { lenis.raf(t); requestAnimationFrame(bucle); })(0);
    }
  }



  /* ======================================================================
     Barra de progreso de lectura
     ====================================================================== */

  function barraProgreso() {
    var barra = uno('.progress span');
    if (!barra) return;

    if (animar) {
      gsap.to(barra, {
        scaleX: 1,
        ease: 'none',
        scrollTrigger: { trigger: document.body, start: 'top top', end: 'max', scrub: 0.3 }
      });
    } else {
      barra.style.transform = 'scaleX(1)';
      barra.style.opacity = '.25';
    }
  }


  /* ======================================================================
     Cabecera: se esconde al bajar, vuelve al subir
     ====================================================================== */

  function cabeceraAlScroll() {
    var cabecera = uno('.site-head');
    if (!cabecera) return;

    var anterior = 0;
    window.addEventListener('scroll', function () {
      var actual = window.scrollY;
      cabecera.classList.toggle('is-hidden', actual > 140 && actual > anterior);
      anterior = actual;
    }, { passive: true });
  }


  /* ======================================================================
     Menú fullscreen
     ====================================================================== */

  function menuFullscreen() {
    var boton   = uno('.menu-btn');
    var overlay = uno('.menu-overlay');
    if (!boton || !overlay) return;

    var enlaces = todos('a', overlay);
    var abierto = false;

    function pintar() {
      uno('.menu-txt', boton).textContent = abierto ? 'Cerrar' : 'Menú';
      boton.setAttribute('aria-expanded', String(abierto));
      overlay.setAttribute('aria-hidden', String(!abierto));
      if (abierto) overlay.removeAttribute('inert');
      else overlay.setAttribute('inert', '');
    }

    function alternar(forzar) {
      abierto = typeof forzar === 'boolean' ? forzar : !abierto;
      pintar();

      if (animar) {
        if (abierto) {
          gsap.set(overlay, { visibility: 'visible' });
          gsap.to(overlay, { clipPath: 'inset(0% 0 0% 0)', duration: 0.7, ease: 'power4.inOut' });
          gsap.fromTo(enlaces,
            { yPercent: 60, opacity: 0 },
            { yPercent: 0, opacity: 1, duration: 0.7, stagger: 0.06, delay: 0.25, ease: 'power3.out' });
          if (lenis) lenis.stop();
        } else {
          gsap.to(overlay, {
            clipPath: 'inset(0 0 100% 0)', duration: 0.6, ease: 'power4.inOut',
            onComplete: function () { gsap.set(overlay, { visibility: 'hidden' }); }
          });
          if (lenis) lenis.start();
        }
      } else {
        overlay.style.clipPath  = abierto ? 'inset(0 0 0% 0)' : 'inset(0 0 100% 0)';
        overlay.style.visibility = abierto ? 'visible' : 'hidden';
      }

      // El foco sigue a lo que se ve: si no, se navega a ciegas con el teclado.
      if (abierto && enlaces[0]) enlaces[0].focus();
      else if (!abierto) boton.focus();
    }

    boton.addEventListener('click', function () { alternar(); });
    enlaces.forEach(function (a) {
      a.addEventListener('click', function () { alternar(false); });
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && abierto) alternar(false);
    });
  }


  /* ======================================================================
     Transición entre páginas
     ====================================================================== */

  function transicionEntrePaginas() {
    var cortina = uno('.transition');
    if (!cortina || !animar) return;

    // Entrada: la cortina se retira hacia arriba.
    gsap.set(cortina, { scaleY: 1, transformOrigin: '50% 0%' });
    gsap.to(cortina, { scaleY: 0, duration: 0.9, ease: 'power4.inOut', delay: 0.1 });

    // Salida: solo para enlaces internos a otra página.
    document.addEventListener('click', function (e) {
      var enlace = e.target.closest('a[href]');
      if (!enlace) return;

      var href = enlace.getAttribute('href');
      if (!href || href.charAt(0) === '#' || enlace.target === '_blank' ||
          /^(mailto:|tel:|https?:)/.test(href)) return;

      e.preventDefault();
      gsap.set(cortina, { transformOrigin: '50% 100%' });
      gsap.to(cortina, {
        scaleY: 1, duration: 0.55, ease: 'power4.inOut',
        onComplete: function () { window.location.href = href; }
      });
    });
  }


  /* ======================================================================
     Anclas suaves
     ====================================================================== */

  function anclasSuaves() {
    todos('a[href^="#"]').forEach(function (enlace) {
      enlace.addEventListener('click', function (e) {
        var id = enlace.getAttribute('href');
        if (id.length > 1 && uno(id)) {
          e.preventDefault();
          irA(id);
        }
      });
    });
  }


  /* ======================================================================
     Hero
     ====================================================================== */

  function hero() {
    var seccion = uno('.hero');
    if (!seccion || !animar) return;

    var letras = [];
    todos('[data-split]', seccion).forEach(function (el) {
      letras = letras.concat(partirEnLetras(el));
    });

    gsap.timeline({ defaults: { ease: 'power4.out' } })
      .from(letras,          { yPercent: 120, duration: 1.15, stagger: 0.022 }, 0.15)
      .from('.hero-top > *', { y: -18, duration: 0.8, stagger: 0.08 }, 0.7)
      .from('.hero-sub > *', { y: 30, duration: 0.9, stagger: 0.1 }, 0.85);

    if (punteroFino) {
      // Cada letra da un saltito al pasar por encima.
      letras.forEach(function (letra) {
        letra.addEventListener('mouseenter', function () {
          gsap.fromTo(letra,
            { yPercent: 0 },
            { yPercent: -12, duration: 0.18, yoyo: true, repeat: 1, ease: 'power2.out' });
        });
      });
    }

    // Deriva al hacer scroll: el titular se va difuminando.
    var recorrido = { trigger: seccion, start: 'top top', end: 'bottom top', scrub: true };
    gsap.to('.hero-title', { yPercent: 18, opacity: 0.25, ease: 'none', scrollTrigger: recorrido });
  }


  /* ======================================================================
     Rotador de palabras del claim
     ====================================================================== */

  function rotadorDePalabras() {
    var caja = uno('.rotator .word-box');
    if (!caja) return;

    var palabras = todos('.word', caja);

    // La caja se fija al ancho de la palabra más larga para que nada salte.
    function medir() {
      var ancho = 0;
      palabras.forEach(function (p) { ancho = Math.max(ancho, p.offsetWidth); });
      if (ancho) caja.style.minWidth = ancho + 'px';
    }
    medir();
    window.addEventListener('load', medir);

    if (!animar || palabras.length < 2) {
      palabras.forEach(function (p, i) {
        p.style.position  = i ? 'absolute' : 'relative';
        p.style.transform = i ? 'translateY(110%)' : 'none';
      });
      return;
    }

    gsap.set(palabras, { yPercent: 110 });
    gsap.set(palabras[0], { yPercent: 0 });

    var actual = 0;
    setInterval(function () {
      var saliente = palabras[actual];
      actual = (actual + 1) % palabras.length;
      var entrante = palabras[actual];

      gsap.to(saliente, { yPercent: -110, duration: 0.55, ease: 'power3.in' });
      gsap.fromTo(entrante,
        { yPercent: 110 },
        { yPercent: 0, duration: 0.55, delay: 0.5, ease: 'power3.out' });
    }, 2400);
  }


  /* ======================================================================
     Revelados al hacer scroll
     ====================================================================== */

  function revelados() {
    if (!animar) return;

    todos('[data-reveal]').forEach(function (el) {
      if (yaALaVista(el)) return;

      var tipo = el.getAttribute('data-reveal');
      // 'top 100%': arranca justo cuando el elemento asoma por abajo, no antes.
      var disparo = { trigger: el, start: 'top 100%', once: true };

      if (tipo === 'clip') {
        gsap.fromTo(el,
          { clipPath: 'inset(100% 0 0 0)' },
          { clipPath: 'inset(0% 0 0 0)', duration: 0.55, ease: 'power3.out',
            scrollTrigger: disparo });
      } else if (tipo === 'lines') {
        gsap.from(todos('.line-mask > span', el), {
          yPercent: 115, duration: 0.7, stagger: 0.06, ease: 'power4.out',
          scrollTrigger: disparo
        });
      } else {
        gsap.from(el, {
          y: 30, opacity: 0, duration: 0.55, ease: 'power3.out',
          scrollTrigger: disparo
        });
      }
    });

    // Rejillas (clientes, proceso, meta…): el retardo entre fichas es mínimo
    // para que la tanda entera esté puesta antes de terminar de entrar.
    todos('[data-reveal-group]').forEach(function (grupo) {
      if (yaALaVista(grupo)) return;
      gsap.from(grupo.children, {
        y: 26, opacity: 0, duration: 0.5, stagger: 0.03, ease: 'power3.out',
        scrollTrigger: { trigger: grupo, start: 'top 100%', once: true }
      });
    });
  }


  /* ======================================================================
     Imágenes: parallax y máscara de entrada
     ====================================================================== */

  function imagenes() {
    if (!animar) return;

    // Parallax interno. El scale 1.12 da margen para que no asomen huecos.
    todos('[data-parallax] img').forEach(function (img) {
      gsap.set(img, { scale: 1.12 });
      gsap.fromTo(img, { yPercent: -5 }, {
        yPercent: 5, ease: 'none',
        scrollTrigger: { trigger: img.parentElement, start: 'top bottom', end: 'bottom top', scrub: true }
      });
    });

    todos('[data-img-reveal]').forEach(function (marco) {
      var img = uno('img', marco);
      // Casi todo el trabajo de este portfolio son listados e infografías con
      // texto pegado al borde: un zoom del 12% se los come. Con
      // data-encuadre="completo" la imagen entra con la cortinilla del marco,
      // pero sin ampliarse ni recortarse.
      var completo = marco.getAttribute('data-encuadre') === 'completo';

      // Si el marco ya se ve, nada de cortinilla: la imagen se muestra tal cual.
      if (yaALaVista(marco)) {
        if (img && !completo) gsap.set(img, { scale: 1.12 });
        return;
      }

      var disparo = { trigger: marco, start: 'top 100%', once: true };

      gsap.fromTo(marco,
        { clipPath: 'inset(0 0 100% 0)' },
        { clipPath: 'inset(0 0 0% 0)', duration: 0.6, ease: 'power3.out', scrollTrigger: disparo });

      if (img && !completo) {
        gsap.fromTo(img,
          { scale: 1.25 },
          { scale: 1.12, duration: 0.8, ease: 'power3.out', scrollTrigger: disparo });
      }
    });

    // Cada imagen que termina de cargar puede cambiar la altura de la página:
    // hay que recalcular los disparadores o se desincronizan.
    var pendiente;
    todos('img').forEach(function (img) {
      if (img.complete) return;
      img.addEventListener('load', function () {
        clearTimeout(pendiente);
        pendiente = setTimeout(refrescarScrollTrigger, 250);
      }, { once: true });
    });

    // Zoom al pasar por encima de un proyecto destacado.
    if (!punteroFino) return;
    todos('.proj-row > a').forEach(function (enlace) {
      var img = uno('.proj-media img', enlace);
      if (!img) return;

      function zoom(escala) {
        gsap.to(img, { scale: escala, duration: 1, ease: 'power3.out', overwrite: 'auto' });
      }
      // Vuelve al 1: la portada del proyecto se ve entera en reposo.
      enlace.addEventListener('mouseenter', function () { zoom(1.06); });
      enlace.addEventListener('mouseleave', function () { zoom(1); });
    });
  }


  /* ======================================================================
     Contadores de las cifras
     ====================================================================== */

  function contadores() {
    if (!animar) return;

    todos('[data-count]').forEach(function (el) {
      var final = parseInt(el.getAttribute('data-count'), 10);
      var sufijo = el.getAttribute('data-suffix') || '';
      var valor = { n: 0 };

      gsap.to(valor, {
        n: final, duration: 1.6, ease: 'power3.out',
        scrollTrigger: { trigger: el, start: 'top 88%' },
        onUpdate: function () { el.textContent = Math.round(valor.n) + sufijo; }
      });
    });
  }


  /* ======================================================================
     Servicios: acordeón
     ====================================================================== */

  function servicios() {
    var filas = todos('.srv-row');
    if (!filas.length) return;

    function cerrar(fila) {
      fila.classList.remove('is-open');
      uno('.srv-head', fila).setAttribute('aria-expanded', 'false');
      var cuerpo = uno('.srv-body', fila);
      if (animar) gsap.to(cuerpo, { height: 0, duration: 0.5, ease: 'power3.inOut' });
      else cuerpo.style.height = '0px';
    }

    filas.forEach(function (fila) {
      var boton  = uno('.srv-head', fila);
      var cuerpo = uno('.srv-body', fila);
      if (!boton || !cuerpo) return;

      boton.addEventListener('click', function () {
        var estabaAbierta = fila.classList.contains('is-open');

        // Solo una abierta a la vez.
        todos('.srv-row.is-open').forEach(function (otra) {
          if (otra !== fila) cerrar(otra);
        });

        fila.classList.toggle('is-open', !estabaAbierta);
        boton.setAttribute('aria-expanded', String(!estabaAbierta));

        if (animar) {
          gsap.to(cuerpo, {
            height: estabaAbierta ? 0 : cuerpo.scrollHeight,
            duration: 0.6, ease: 'power3.inOut',
            onComplete: function () {
              // 'auto' deja que el contenido crezca si cambia el ancho.
              if (!estabaAbierta) cuerpo.style.height = 'auto';
              refrescarScrollTrigger();
            }
          });
        } else {
          cuerpo.style.height = estabaAbierta ? '0px' : 'auto';
        }
      });
    });
  }


  /* ======================================================================
     Filtros del archivo de clientes
     ====================================================================== */

  function filtrosArchivo() {
    var botones = todos('.filter-btn');
    var fichas  = todos('.arch-item');
    if (!botones.length || !fichas.length) return;

    botones.forEach(function (boton) {
      boton.addEventListener('click', function () {
        botones.forEach(function (b) { b.classList.remove('is-active'); });
        boton.classList.add('is-active');

        var filtro = boton.getAttribute('data-filter');

        fichas.forEach(function (ficha) {
          var categorias = (ficha.getAttribute('data-cats') || '').split(' ');
          var visible = filtro === 'todos' || categorias.indexOf(filtro) !== -1;

          if (!animar) {
            ficha.classList.toggle('is-out', !visible);
          } else if (visible && ficha.classList.contains('is-out')) {
            ficha.classList.remove('is-out');
            gsap.fromTo(ficha,
              { opacity: 0, scale: 0.95 },
              { opacity: 1, scale: 1, duration: 0.5, ease: 'power3.out' });
          } else if (!visible) {
            ficha.classList.add('is-out');
          }
        });

        // La rejilla cambia de alto: los disparadores de abajo se mueven.
        if (animar) setTimeout(refrescarScrollTrigger, 350);
      });
    });
  }


  /* ======================================================================
     Botones magnéticos
     ====================================================================== */

  function botonesMagneticos() {
    if (!punteroFino || !animar) return;

    todos('.btn, .menu-btn').forEach(function (boton) {
      boton.addEventListener('mousemove', function (e) {
        var caja = boton.getBoundingClientRect();
        gsap.to(boton, {
          x: (e.clientX - caja.left - caja.width / 2) * 0.3,
          y: (e.clientY - caja.top - caja.height / 2) * 0.4,
          duration: 0.5, ease: 'power3.out'
        });
      });
      boton.addEventListener('mouseleave', function () {
        gsap.to(boton, { x: 0, y: 0, duration: 0.7, ease: 'elastic.out(1,0.4)' });
      });
    });
  }


  /* ======================================================================
     Portada del case study
     ====================================================================== */

  function portadaCaseStudy() {
    var img = uno('.case-cover img');
    if (!img || !animar) return;

    gsap.fromTo(img, { yPercent: -4 }, {
      yPercent: 4, ease: 'none',
      scrollTrigger: { trigger: '.case-cover', start: 'top bottom', end: 'bottom top', scrub: true }
    });
  }


  /* ======================================================================
     Formulario de contacto

     El envío lo hace FormSubmit; aquí solo se comprueban los campos y se
     manda por detrás para no sacar al visitante de la página. Sin JS (o si
     falla el fetch) el formulario se envía solo, con su POST de toda la vida.
     ====================================================================== */

  function formularioContacto() {
    var form = uno('[data-form-contacto]');
    if (!form || !window.fetch) return;   // sin fetch, que lo mande el navegador

    var destino = form.getAttribute('data-form-contacto');
    var boton   = uno('button[type="submit"]', form);
    var aviso   = uno('.form-aviso', form);
    var textoBoton = boton.textContent;
    var campos  = todos('input[data-error], textarea[data-error]', form);

    function marcar(campo, mal) {
      var caja = campo.closest('.field');
      var msg  = uno('.error', caja);

      caja.classList.toggle('is-error', mal);
      campo.setAttribute('aria-invalid', mal ? 'true' : 'false');

      if (mal && !msg) {
        msg = document.createElement('span');
        msg.className = 'error';
        msg.textContent = campo.getAttribute('data-error');
        caja.appendChild(msg);
      } else if (!mal && msg) {
        caja.removeChild(msg);
      }
    }

    /* El propio navegador ya sabe si un campo requerido está vacío o si el
       correo tiene forma de correo: se aprovecha en vez de reinventarlo. */
    function valido(campo) {
      // El required del navegador da por bueno un campo con solo espacios.
      if (campo.required && campo.value.trim() === '') return false;
      return campo.checkValidity ? campo.checkValidity() : true;
    }

    function decir(texto, clase) {
      aviso.textContent = texto;
      aviso.className = 'form-aviso' + (clase ? ' ' + clase : '');
    }

    // Al corregir un campo ya señalado, el aviso se va solo.
    campos.forEach(function (campo) {
      campo.addEventListener('input', function () {
        if (campo.closest('.field').classList.contains('is-error') && valido(campo)) {
          marcar(campo, false);
        }
      });
      campo.addEventListener('blur', function () {
        if (campo.value.trim() !== '') marcar(campo, !valido(campo));
      });
    });

    form.addEventListener('submit', function (e) {
      var primerFallo = null;

      campos.forEach(function (campo) {
        var mal = !valido(campo);
        marcar(campo, mal);
        if (mal && !primerFallo) primerFallo = campo;
      });

      if (primerFallo) {
        e.preventDefault();
        decir('', '');
        primerFallo.focus();
        return;
      }

      e.preventDefault();
      form.classList.add('is-enviando');
      boton.textContent = form.getAttribute('data-enviando');
      decir('', '');

      fetch(destino, {
        method: 'POST',
        headers: { 'Accept': 'application/json' },
        body: new FormData(form)
      })
        .then(function (r) {
          if (!r.ok) throw new Error(r.status);
          return r.json();
        })
        .then(function () {
          form.reset();
          decir(form.getAttribute('data-exito'), 'ok');
        })
        .catch(function () {
          decir(form.getAttribute('data-error'), 'mal');
        })
        .then(function () {
          form.classList.remove('is-enviando');
          boton.textContent = textoBoton;
        });
    });
  }


  /* ======================================================================
     Año del pie
     ====================================================================== */

  function anioActual() {
    todos('[data-year]').forEach(function (el) {
      el.textContent = new Date().getFullYear();
    });
  }


  /* ---------------------------------------------------------------- arranque */

  [
    scrollSuave,
    barraProgreso,
    cabeceraAlScroll,
    menuFullscreen,
    anclasSuaves,
    hero,
    rotadorDePalabras,
    revelados,
    imagenes,
    contadores,
    servicios,
    filtrosArchivo,
    botonesMagneticos,
    portadaCaseStudy,
    formularioContacto,
    anioActual,
    transicionEntrePaginas   // el último: pinta la cortina de entrada
  ].forEach(function (modulo) { modulo(); });

  window.addEventListener('load', refrescarScrollTrigger);
})();
