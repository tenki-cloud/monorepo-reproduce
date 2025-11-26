export default function Home() {
  return (
    <main style={{ padding: "2rem", fontFamily: "system-ui" }}>
      <h1>Vercel Test App 4</h1>
      <p>This is a minimal Next.js app for testing Vercel rate limits.</p>
      <p>Deploy timestamp: {new Date().toISOString()}</p>
    </main>
  );
}
