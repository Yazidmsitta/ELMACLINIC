"use client";

import Image from "next/image";
import { useEffect, useState } from "react";
import BookingForm from "./BookingForm";

const serviceImages = ["elma-3.webp", "elma-5.webp", "elma-banner-36.webp", "elma-14.webp"];
const socialImages = [
  "elma-clinic-elmaclinic-kenitra-maroc-morocco.webp",
  "elma-clinic-elmaclinic-kenitra-maroc-morocco-3.webp",
  "elma-clinic-elmaclinic-kenitra-maroc-morocco-4.webp",
  "elma-clinic-elmaclinic-kenitra-maroc-morocco-5.webp",
  "elma-clinic-elmaclinic-kenitra-maroc-morocco-58.webp",
];

function Icon({ children }) {
  return <span className="material-symbols-rounded" aria-hidden="true">{children}</span>;
}

function scrollToSection(id) {
  document.getElementById(id)?.scrollIntoView({ behavior: "smooth", block: "start" });
}

export default function HomePage({ catalog, catalogLive, whatsapp }) {
  const [menuOpen, setMenuOpen] = useState(false);
  const services = Array.isArray(catalog.services) ? catalog.services : [];

  useEffect(() => {
    const elements = document.querySelectorAll(".reveal");
    if (!("IntersectionObserver" in window) || window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      elements.forEach((element) => element.classList.add("is-visible"));
      return undefined;
    }
    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      });
    }, { threshold: 0.12, rootMargin: "0px 0px -40px" });
    elements.forEach((element) => observer.observe(element));
    return () => observer.disconnect();
  }, []);

  function navigate(id) {
    setMenuOpen(false);
    scrollToSection(id);
  }

  const adviceMessage = encodeURIComponent("Bonjour ELMACLINIC, je souhaite un conseil pour choisir le soin adapté.");

  return (
    <>
      <a className="skip-link" href="#main-content">Aller au contenu</a>
      <div className="site-shell">
        <header className="topbar">
          <button className="brand" type="button" onClick={() => navigate("accueil")} aria-label="ELMACLINIC — Accueil">
            <Image src="/assets/logo-nav.svg" alt="ELMACLINIC" width={180} height={72} priority />
          </button>
          <nav className={`main-nav ${menuOpen ? "is-open" : ""}`} aria-label="Navigation principale">
            <button type="button" onClick={() => navigate("soins")}>Soins</button>
            <button type="button" onClick={() => navigate("clinique")}>La clinique</button>
            <button type="button" onClick={() => navigate("avis")}>Avis</button>
            <button type="button" onClick={() => navigate("contact")}>Contact</button>
          </nav>
          <div className="header-actions">
            <button className="header-cta" type="button" onClick={() => navigate("reservation")}>Réserver</button>
            <button className="menu-toggle" type="button" aria-label="Ouvrir le menu" aria-expanded={menuOpen} onClick={() => setMenuOpen((open) => !open)}><Icon>{menuOpen ? "close" : "menu"}</Icon></button>
          </div>
        </header>

        <main id="main-content" className="site-main">
          <section className="hero" id="accueil" aria-labelledby="hero-title">
            <div className="hero-copy reveal">
              <p className="eyebrow">Institut de beauté & soins experts · Kénitra</p>
              <h1 id="hero-title">La beauté,<br /><em>précise.</em></h1>
              <p className="hero-intro">Laser, skincare et rituels experts pensés autour de votre peau, de vos besoins et de votre rythme.</p>
            </div>
            <div className="reveal">
              <BookingForm services={services} whatsapp={whatsapp} />
              {!catalogLive && <p className="catalog-notice">Mode aperçu : ajoutez les secrets API dans Vercel pour charger les services réels.</p>}
            </div>
          </section>

          <section className="section services-section" id="soins" aria-labelledby="services-title">
            <div className="section-head reveal">
              <div><p className="kicker">Notre expertise</p><h2 id="services-title">Des soins qui vont<br />à l’essentiel.</h2></div>
              <p>Une sélection ciblée de protocoles, expliqués clairement et adaptés après diagnostic.</p>
            </div>
            <div className="service-grid">
              {services.slice(0, 4).map((service, index) => (
                <article className="service-card reveal" key={service.id} style={{ "--delay": `${index * 60}ms` }}>
                  <button type="button" className="service-link" onClick={() => navigate("reservation")}>
                    <span className="service-media"><Image src={`/assets/${serviceImages[index] || serviceImages[0]}`} alt="" fill sizes="(max-width: 620px) 83vw, (max-width: 1160px) 50vw, 25vw" /></span>
                    <span className="service-meta"><span>{String(index + 1).padStart(2, "0")}</span><Icon>north_east</Icon></span>
                    <h3>{service.name}</h3>
                    <p>{service.description || "Un protocole précis et adapté à vos besoins."}</p>
                    {service.price_centimes > 0 && <strong>À partir de {Math.round(service.price_centimes / 100)} DH</strong>}
                  </button>
                </article>
              ))}
            </div>
          </section>

          <section className="section advice-section" aria-labelledby="advice-title">
            <div className="advice-copy reveal">
              <p className="kicker">Consultation WhatsApp</p>
              <h2 id="advice-title">Vous hésitez entre plusieurs soins ?</h2>
              <p>Expliquez-nous votre besoin et envoyez une photo si nécessaire. L’équipe vous orientera avant la réservation.</p>
              <a className="button button-dark" href={`https://wa.me/${whatsapp}?text=${adviceMessage}`} target="_blank" rel="noreferrer"><Icon>chat</Icon> Demander un conseil</a>
            </div>
            <div className="advice-image reveal"><Image src="/assets/elma-clinic-elmaclinic-kenitra-maroc-morocco-5.webp" alt="Consultation personnalisée ELMACLINIC" fill sizes="(max-width: 900px) 100vw, 50vw" /></div>
          </section>

          <section className="section expertise-section" id="clinique" aria-labelledby="expertise-title">
            <div className="expertise-words reveal"><span>Expertise.</span><span>Technologie.</span><span>Suivi.</span></div>
            <div className="expertise-layout">
              <div className="expertise-image reveal"><Image src="/assets/hero.webp" alt="Accueil ELMACLINIC à Kénitra" fill sizes="(max-width: 900px) 100vw, 55vw" /></div>
              <div className="expertise-copy reveal">
                <p className="kicker">Une approche sur mesure</p>
                <h2 id="expertise-title">Comprendre avant de traiter.</h2>
                <p>Chaque protocole commence par l’écoute et le diagnostic. L’objectif n’est pas d’en faire plus, mais de choisir ce qui est juste pour vous.</p>
                <ul className="proof-list">
                  <li><Icon>clinical_notes</Icon><div><strong>Diagnostic</strong><small>Pour orienter le protocole.</small></div></li>
                  <li><Icon>verified_user</Icon><div><strong>Protocoles encadrés</strong><small>Précision, hygiène et confort.</small></div></li>
                  <li><Icon>monitoring</Icon><div><strong>Suivi</strong><small>Des séances ajustées à votre évolution.</small></div></li>
                </ul>
              </div>
            </div>
          </section>

          <section className="section reviews-section" id="avis" aria-labelledby="reviews-title">
            <div className="section-head reveal">
              <div><p className="kicker">Avis Google</p><h2 id="reviews-title">La confiance se construit<br />dans chaque détail.</h2></div>
              <div className="rating-mark"><span>Google</span><strong>★★★★★</strong></div>
            </div>
            <div className="integration-placeholder reveal"><Icon>reviews</Icon><div><strong>Avis vérifiés, bientôt ici.</strong><p>Le developer peut brancher le profil Google Business ou un widget d’avis dans ce composant.</p></div></div>
          </section>

          <section className="section social-section" aria-labelledby="social-title">
            <div className="social-head reveal"><h2 id="social-title">Suivez-nous sur Instagram</h2><a href="https://www.instagram.com/elmaclinic_maroc" target="_blank" rel="noreferrer">@elmaclinic_maroc <Icon>arrow_outward</Icon></a></div>
            <div className="social-grid reveal">
              {socialImages.map((image) => <a href="https://www.instagram.com/elmaclinic_maroc" target="_blank" rel="noreferrer" key={image}><Image src={`/assets/${image}`} alt="ELMACLINIC sur Instagram" fill sizes="(max-width: 900px) 33vw, 20vw" /></a>)}
            </div>
          </section>

          <section className="contact-section" id="contact" aria-labelledby="contact-title">
            <div className="contact-copy reveal">
              <p className="kicker">Nous trouver</p>
              <h2 id="contact-title">Votre prochain<br />moment commence ici.</h2>
              <div className="contact-actions">
                <button className="button button-light" type="button" onClick={() => navigate("reservation")}>Réserver en ligne <Icon>arrow_upward</Icon></button>
                <a className="button button-outline-light" href={`https://wa.me/${whatsapp}?text=${adviceMessage}`} target="_blank" rel="noreferrer">Consultation WhatsApp</a>
              </div>
              <div className="contact-details">
                <div><small>Adresse</small><p>Angle Av. Mohamed Diouri, Kénitra</p></div>
                <div><small>Contact</small><p><a href="tel:+212666541050">+212 6 66 54 10 50</a><br /><a href="mailto:elmakhfiwiclinic@gmail.com">elmakhfiwiclinic@gmail.com</a></p></div>
                <div><small>Horaires</small><p>Lun—Sam · 10:00—21:00</p></div>
              </div>
            </div>
            <div className="map-wrap reveal"><iframe title="ELMACLINIC sur Google Maps" src="https://www.google.com/maps?q=ELMA%20Clinic%20Kenitra%20Morocco&output=embed" loading="lazy" referrerPolicy="no-referrer-when-downgrade" /></div>
            <footer className="site-footer">
              <div className="site-footer-brand">
                <Image src="/assets/logo-nav.svg" alt="ELMACLINIC" width={170} height={64} />
              </div>
              <p className="site-footer-center">Beauté experte · Kénitra</p>
              <div className="site-footer-actions">
                <p>© {new Date().getFullYear()} ELMACLINIC</p>
                <a className="button button-light footer-whatsapp" href={`https://wa.me/${whatsapp}?text=${adviceMessage}`} target="_blank" rel="noreferrer"><Icon>chat</Icon><span>WhatsApp</span></a>
              </div>
            </footer>
          </section>
        </main>
      </div>
      <a className="whatsapp-float" href={`https://wa.me/${whatsapp}?text=${adviceMessage}`} target="_blank" rel="noreferrer" aria-label="Ouvrir WhatsApp"><Icon>chat</Icon><span>WhatsApp</span></a>
    </>
  );
}
