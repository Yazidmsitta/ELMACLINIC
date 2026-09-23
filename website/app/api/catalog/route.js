import { NextResponse } from "next/server";
import { fetchCatalog } from "@/lib/elma-api";

export const dynamic = "force-dynamic";

export async function GET(request) {
  const page = request.nextUrl.searchParams.get("page") || "1";
  try {
    return NextResponse.json(await fetchCatalog(page));
  } catch (error) {
    console.error("ELMA catalog error", error);
    return NextResponse.json(
      { message: "Le catalogue est momentanément indisponible." },
      { status: error.status || 503 }
    );
  }
}
