import Link from "next/link";

export const metadata = { title: "Page introuvable", robots: { index: false, follow: true } };

export default function NotFound() {
  return (
    <main className="not-found-page">
      <p>404</p>
      <h1>Cette page n’existe plus.</h1>
      <Link className="button button-dark" href="/">Retour à l’accueil</Link>
    </main>
  );
}
