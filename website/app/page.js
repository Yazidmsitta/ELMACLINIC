import HomePage from "@/components/HomePage";
import { fetchCatalog } from "@/lib/elma-api";
import { previewCatalog } from "@/lib/preview-catalog";

export const dynamic = "force-dynamic";

export default async function Page() {
  let catalog = previewCatalog;
  let catalogLive = false;

  try {
    catalog = await fetchCatalog(1);
    catalogLive = true;
  } catch (error) {
    console.warn("ELMA catalog preview fallback", error.message);
  }

  const normalizedCatalog = {
    currency: catalog.currency || "MAD",
    categories: Array.isArray(catalog.categories) ? catalog.categories : [],
    services: Array.isArray(catalog.services) ? catalog.services : previewCatalog.services,
    practitioners: Array.isArray(catalog.practitioners) ? catalog.practitioners : [],
  };

  return (
    <HomePage
      catalog={normalizedCatalog}
      catalogLive={catalogLive}
      whatsapp={(process.env.NEXT_PUBLIC_ELMA_WHATSAPP || "212631396958").replace(/\D/g, "")}
    />
  );
}
