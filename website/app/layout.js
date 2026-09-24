import { DM_Sans, Syne } from "next/font/google";
import "./globals.css";

const bodyFont = DM_Sans({
  subsets: ["latin"],
  variable: "--font-body",
  display: "swap",
});

const displayFont = Syne({
  subsets: ["latin"],
  variable: "--font-display",
  display: "swap",
});

export const metadata = {
  metadataBase: new URL("https://elmaclinic.com"),
  title: {
    default: "ELMACLINIC | Laser, skincare & esthétique à Kénitra",
    template: "%s | ELMACLINIC",
  },
  description:
    "ELMACLINIC à Kénitra : épilation laser, soins du visage, head spa et rituels bien-être avec diagnostic et suivi personnalisé.",
  alternates: { canonical: "/" },
  openGraph: {
    type: "website",
    locale: "fr_MA",
    url: "/",
    siteName: "ELMACLINIC",
    title: "ELMACLINIC | La beauté, précise.",
    description: "Laser, skincare et soins experts à Kénitra.",
    images: [{ url: "/assets/elma-hero-editorial.webp", width: 1600, height: 1000 }],
  },
  robots: { index: true, follow: true },
};

export default function RootLayout({ children }) {
  return (
    <html lang="fr">
      <head>
        <link
          href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded:opsz,wght,FILL@20..48,300,0..1&display=swap"
          rel="stylesheet"
        />
      </head>
      <body className={`${bodyFont.variable} ${displayFont.variable}`}>
        {children}
      </body>
    </html>
  );
}
