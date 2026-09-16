<?php

namespace App\Services;

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

class MailService
{
    public static function sendInvoiceEmail(string $to, string $subject, string $text, string $pdfString, string $filename): bool
    {
        $mail = new PHPMailer(true);

        try {
            $mail->isSMTP();
            $mail->Host       = $_ENV['SMTP_HOST'] ?? 'smtp.gmail.com';
            $mail->SMTPAuth   = true;
            $mail->Username   = $_ENV['SMTP_USER'] ?? '';
            $mail->Password   = $_ENV['SMTP_PASS'] ?? '';
            $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
            $mail->Port       = (int)($_ENV['SMTP_PORT'] ?? 587);

            $fromEmail = $_ENV['SMTP_USER'] ?? 'support.pedantick@gmail.com';
            $mail->setFrom($fromEmail, 'Printout Billing System');
            $mail->addAddress($to);

            $mail->addStringAttachment($pdfString, $filename, 'base64', 'application/pdf');

            $mail->isHTML(false);
            $mail->Subject = $subject;
            $mail->Body    = $text;

            return $mail->send();
        } catch (Exception $e) {
            throw new \RuntimeException("Email sending failed: {$mail->ErrorInfo}");
        }
    }
}
