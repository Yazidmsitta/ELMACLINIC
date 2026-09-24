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

  const getCasablancaToday = () => {
    const parts = new Intl.DateTimeFormat("en-CA", {
      timeZone: "Africa/Casablanca",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    }).formatToParts(new Date());
    const valuesByType = {};
    parts.forEach((part) => {
      if (part.type !== "literal") valuesByType[part.type] = part.value;
    });
    return {
      date: `${valuesByType.year}-${valuesByType.month}-${valuesByType.day}`,
      minutes: Number(valuesByType.hour) * 60 + Number(valuesByType.minute),
    };
  };

  const allTimes = useMemo(() => {
    const slots = [];
    for (let minutes = 10 * 60; minutes <= 20 * 60 + 30; minutes += 30) {
      const hour = String(Math.floor(minutes / 60)).padStart(2, "0");
      const minute = String(minutes % 60).padStart(2, "0");
      slots.push(`${hour}:${minute}`);
    }
    return slots;
  }, []);

  const availableTimes = useMemo(() => {
    if (!values.date) return allTimes;
    const casablancaNow = getCasablancaToday();
    const isToday = values.date === casablancaNow.date;
    if (!isToday) return allTimes;

    return allTimes.filter((slot) => {
      const [slotHour, slotMinute] = slot.split(":").map(Number);
      return slotHour * 60 + slotMinute > casablancaNow.minutes;
    });
  }, [allTimes, values.date]);

  const selectedService = services.find((service) => service.id === values.service_id)?.name;
  const whatsappMessage = [
    "Bonjour ELMACLINIC, je souhaite prendre rendez-vous.",
    selectedService ? `Soin : ${selectedService}` : "",
    values.date ? `Date : ${values.date}` : "",
    values.time ? `Heure : ${values.time}` : "",
    values.full_name ? `Nom : ${values.full_name}` : "",
  ].filter(Boolean).join("\n");

  function updateValue(event) {
    const { name, value } = event.target;
    if (!(name in values)) return;
    setValues((current) => {
      const next = { ...current, [name]: value };
      if (name === "date") next.time = "";
      return next;
    });
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

        <label className="field"><span>Date</span><input name="date" type="date" min={today} value={values.date} onChange={updateValue} required /></label>
        <label className="field"><span>Heure souhaitée</span>
          <select name="time" value={values.time} onChange={updateValue} required>
            <option value="">{values.date ? (availableTimes.length ? "Choisir une heure" : "Aucune heure disponible") : "Choisir une date d’abord"}</option>
            {(values.date ? availableTimes : allTimes).map((time) => (
              <option key={time} value={time}>{time}</option>
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
