import "server-only";
import crypto from "node:crypto";

const API_BASE_URL = (
  process.env.ELMA_API_BASE_URL || "https://elmaclinic-api.vercel.app/api/v1"
).replace(/\/$/, "");

function secretBuffer(secretHex, variableName) {
  if (!secretHex || !/^[a-f\d]+$/i.test(secretHex) || secretHex.length % 2 !== 0) {
    throw new Error(`${variableName} is missing or invalid.`);
  }
  return Buffer.from(secretHex, "hex");
}

function signatureHeaders(secretHex, signedValue, variableName) {
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const signature = crypto
    .createHmac("sha256", secretBuffer(secretHex, variableName))
    .update(`${timestamp}.${signedValue}`)
    .digest("hex");

  return {
    timestamp,
    headers: {
      "x-elma-timestamp": timestamp,
      "x-elma-signature": `sha256=${signature}`,
    },
  };
}

async function readJson(response) {
  const data = await response.json().catch(() => null);
  if (!response.ok) {
    const error = new Error(data?.message || "ELMA API request failed.");
    error.status = response.status;
    throw error;
  }
  return data;
}

export async function fetchCatalog(page = 1) {
  const safePage = Number.isInteger(Number(page)) && Number(page) > 0 ? Number(page) : 1;
  const pathWithQuery = `/api/v1/integrations/catalog?page=${safePage}`;
  const { headers } = signatureHeaders(
    process.env.WEBSITE_CATALOG_SECRET_HEX,
    `GET.${pathWithQuery}`,
    "WEBSITE_CATALOG_SECRET_HEX"
  );

  const response = await fetch(`${API_BASE_URL}/integrations/catalog?page=${safePage}`, {
    headers,
    cache: "no-store",
  });
  return readJson(response);
}

function requiredString(value, field, maxLength = 200) {
  const clean = typeof value === "string" ? value.trim() : "";
  if (!clean || clean.length > maxLength) {
    const error = new Error(`Champ invalide: ${field}.`);
    error.status = 422;
    throw error;
  }
  return clean;
}

function optionalString(value, maxLength = 1000) {
  return typeof value === "string" ? value.trim().slice(0, maxLength) : "";
}

export function createBookingPayload(input) {
  const fullName = requiredString(input.full_name, "full_name", 120);
  const phone = requiredString(input.phone, "phone", 30);
  const serviceId = requiredString(input.service_id, "service_id", 120);
  const date = requiredString(input.date, "date", 10);
  const time = requiredString(input.time, "time", 5);
  const timezoneOffset = process.env.ELMA_TIMEZONE_OFFSET || "+01:00";

  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !/^\d{2}:\d{2}$/.test(time)) {
    const error = new Error("Date ou heure invalide.");
    error.status = 422;
    throw error;
  }

  const identifier = crypto.randomUUID();
  const normalizedPhone = phone.replace(/\D/g, "");
  const notes = optionalString(input.notes, 500);

  return {
    provider: "elmaclinic.ma",
    event_id: `website-event-${identifier}`,
    booking_id: `website-booking-${identifier}`,
    occurred_at: new Date().toISOString(),
    source: "WEBSITE",
    starts_at: `${date}T${time}:00${timezoneOffset}`,
    client: {
      external_id: `client-phone-${normalizedPhone}`,
      full_name: fullName,
      phone,
      email: optionalString(input.email, 160) || null,
    },
    practitioner_external_id: optionalString(input.practitioner_id, 120) || null,
    service_external_ids: [serviceId],
    notes: notes || "Réservation depuis elmaclinic.com.",
  };
}

export async function submitBooking(input) {
  const booking = createBookingPayload(input);
  const rawBody = JSON.stringify(booking);
  const { headers } = signatureHeaders(
    process.env.WEBSITE_WEBHOOK_SECRET_HEX,
    rawBody,
    "WEBSITE_WEBHOOK_SECRET_HEX"
  );

  const response = await fetch(`${API_BASE_URL}/integrations/website-bookings`, {
    method: "POST",
    headers: { ...headers, "content-type": "application/json" },
    body: rawBody,
    cache: "no-store",
  });
  return readJson(response);
}
