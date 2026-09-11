import { Features } from "@/components/Features";
import { Footer } from "@/components/Footer";
import { Hero } from "@/components/Hero";
import { Install } from "@/components/Install";
import { Nav } from "@/components/Nav";
import { Privacy } from "@/components/Privacy";
import { Sources } from "@/components/Sources";

export default function Home() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <Sources />
        <Features />
        <Install />
        <Privacy />
      </main>
      <Footer />
    </>
  );
}
