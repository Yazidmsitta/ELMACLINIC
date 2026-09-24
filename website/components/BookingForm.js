"use client";

import { useMemo, useState } from "react";

function Icon({ children }) {
  return <span className="material-symbols-rounded" aria-hidden="true">{children}</span>;
}

export default function BookingForm({ services, whatsapp }) {
  const [state, setState] = useState("idle");
  const [message, setMessage] = useState("Demande soumise à validation selon les disponibilités.");
  const [values, setValues] = useState({ service_id: "", date: "", time: "", full_name: "" });
  const today = useMemo(() => {
    const now = new Date();
    return new Date(now.getTime() - now.getTimezoneOffset() * 60000).toISOString().slice(0, 10);
  }, []);

  const availableTimes = useMemo(() => {
    const slots = [];
    for (let hour = 10; hour <= 20; hour += 1) {
      for (const minute of ["00", "30"]) {
        const time = `${String(hour).padStart(2, "0")}:${minute}`;
        if (time >= "10:00" && time <= "20:30") slots.push(time);
      }
    }
    return slots;
  }, []);

  const selectedService = services.find((service) => service.id === values.service_id)?.name;
  const whatsappMessage = [
    "Bonjour ELMA Clinic, je souhaite prendre rendez-vous.",
    selectedService ? `Soin : ${selectedService}` : "",
    values.date ? `Date : ${values.date}` : "",
    values.time ? `Heure : ${values.time}` : "",
    values.full_name ? `Nom : ${values.full_name}` : "",
  ].filter(Boolean).join("\n");

  function updateValue(event) {
    const { name, value } = event.target;
    if (name === "time" && value && !availableTimes.includes(value)) {
      setValues((current) => ({ ...current, [name]: "" }));
      setMessage("Veuillez choisir une heure proposée parmi les créneaux disponibles.");
      setState("error");
      return;
    }
    if (name in values) setValues((current) => ({ ...current, [name]: value }));
  }

  async function submit(event) {
    event.preventDefault();
    setState("pending");
    setMessage("Envoi en cours…");

    const form = event.currentTarget;
    const data = Object.fromEntries(new FormData(form).entries());

    try {
      const response = await fetch("/api/bookings", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(data),
      });
      const result = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(result.message || "La demande n’a pas pu être envoyée.");

      setState("success");
      setMessage(result.message);
      form.reset();
      setValues({ service_id: "", date: "", time: "", full_name: "" });
    } catch (error) {
      setState("error");
      setMessage(error.message);
    }
  }

  return (
    <div className="booking-panel" id="reservation">
      <div className="booking-heading">
        <div>
          <p className="kicker">Prendre rendez-vous</p>
          <h2>Votre soin, votre moment.</h2>
        </div>
        <span className="booking-note"><Icon>verified</Icon> Confirmation par l’équipe</span>
      </div>

      <form className="booking-form" onSubmit={submit} onChange={updateValue}>
        <label className="field field-service">
          <span>Soin</span>
          <select name="service_id" required defaultValue="">
            <option value="">Choisir un soin</option>
            {services.map((service) => (
              <option key={service.id} value={service.id}>
                {service.name}{service.duration_minutes ? ` · ${service.duration_minutes} min` : ""}
              </option>
            ))}
          </select>
        </label>

        <label className="field"><span>Date</span><input name="date" type="date" min={today} required /></label>
        <label className="field">
          <span>Heure souhaitée</span>
          <select name="time" value={values.time} required onChange={updateValue}>
            <option value="">Choisir une heure</option>
            {availableTimes.map((slot) => (
              <option key={slot} value={slot}>{slot}</option>
            ))}
          </select>
        </label>
        <label className="field"><span>Nom</span><input name="full_name" autoComplete="name" placeholder="Votre nom" required /></label>
        <label className="field"><span>Téléphone</span><input name="phone" type="tel" inputMode="tel" autoComplete="tel" placeholder="06 12 34 56 78" required /></label>
        <label className="field"><span>Email <small>optionnel</small></span><input name="email" type="email" autoComplete="email" placeholder="vous@email.com" /></label>
        <label className="honeypot" aria-hidden="true">Site web<input name="website" tabIndex="-1" autoComplete="off" /></label>

        <div className="booking-submit">
          <button className="button button-dark" type="submit" disabled={state === "pending"}>
            {state === "pending" ? "Envoi…" : "Demander un rendez-vous"}<Icon>arrow_forward</Icon>
          </button>
          <a className="button button-whatsapp" href={`https://wa.me/${whatsapp}?text=${encodeURIComponent(whatsappMessage)}`} target="_blank" rel="noreferrer"><Icon>chat</Icon> WhatsApp</a>
        </div>
        <p className={`form-status ${state === "error" ? "is-error" : ""} ${state === "success" ? "is-success" : ""}`} role="status" aria-live="polite">{message}</p>
      </form>
    </div>
  );
}
