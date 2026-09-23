import { NextResponse } from "next/server";
import { submitBooking } from "@/lib/elma-api";

export async function POST(request) {
  try {
    const input = await request.json();
    if (input.website) {
      return NextResponse.json({ message: "Demande invalide." }, { status: 400 });
    }
    const result = await submitBooking(input);
    return NextResponse.json({
      message: "Demande bien reçue. Notre équipe vous contactera pour confirmer.",
      booking: result,
    });
  } catch (error) {
    console.error("ELMA booking error", error);
    return NextResponse.json(
      { message: error.status === 422 ? error.message : "La réservation est momentanément indisponible." },
      { status: error.status || 503 }
    );
  }
}
