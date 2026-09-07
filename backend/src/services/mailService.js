// CHANGE-2026-09-07: Created Nodemailer MailService for sending invoice PDFs via Node.js backend.

const nodemailer = require('nodemailer');

/**
 * Creates Nodemailer transporter using environment variables.
 */
function createTransporter() {
  const host = process.env.SMTP_HOST || 'smtp.gmail.com';
  const port = parseInt(process.env.SMTP_PORT || '587', 10);
  const secure = process.env.SMTP_SECURE === 'true' || port === 465;
  const user = process.env.NODE_MAILER_ID || process.env.SMTP_USER;
  const pass = process.env.NODE_MAILER_SECRET || process.env.SMTP_PASSWORD || process.env.SMTP_PASS;

  if (!user || !pass) {
    throw new Error('Nodemailer credentials are not configured on the Node.js server (.env). Please set NODE_MAILER_ID and NODE_MAILER_SECRET.');
  }

  return nodemailer.createTransport({
    service: 'gmail',
    host,
    port,
    secure,
    auth: { user, pass }
  });
}

/**
 * Sends an email with an attached PDF document.
 * @param {Object} params
 * @param {string} params.to - Recipient email address
 * @param {string} params.subject - Email subject line
 * @param {string} params.text - Plaintext body
 * @param {Buffer} params.pdfBuffer - Generated PDF attachment buffer
 * @param {string} params.filename - PDF attachment filename
 */
async function sendInvoiceEmail({ to, subject, text, pdfBuffer, filename }) {
  if (!to || !to.trim()) {
    throw new Error('Recipient email address is required.');
  }

  const transporter = createTransporter();
  const mailFrom = process.env.MAIL_FROM || process.env.NODE_MAILER_ID || process.env.SMTP_USER;

  const mailOptions = {
    from: mailFrom,
    to: to.trim(),
    subject: subject || 'Invoice PDF',
    text: text || 'Please find attached your invoice PDF.',
    attachments: [
      {
        filename: filename || 'Invoice.pdf',
        content: pdfBuffer,
        contentType: 'application/pdf'
      }
    ]
  };

  const info = await transporter.sendMail(mailOptions);
  return info;
}

module.exports = {
  sendInvoiceEmail
};
