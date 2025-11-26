export const metadata = {
  title: "Vercel Test App 7",
  description: "Testing Vercel rate limits",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
