export const metadata = {
  title: "Vercel Test App 4",
  description: "Testing Vercel rate limits",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
