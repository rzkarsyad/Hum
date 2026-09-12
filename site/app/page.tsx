import { Footer } from "@/components/Footer";
import { Hero } from "@/components/Hero";
import { Nav } from "@/components/Nav";
import { Sources } from "@/components/Sources";
import { Specs } from "@/components/Specs";

export default function Home() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <Sources />
        <Specs />
      </main>
      <Footer />
    </>
  );
}
