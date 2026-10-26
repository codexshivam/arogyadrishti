"""Zero-Cost Notification Routing Engine (`NotificationService`) for Government of Nepal DPI.

Strictly separates Authentication (+977 Phone SMS OTP ONLY) from System Notifications & Alerts:
- Intercepts system events (`SLA_BREACH`, `RRT_DISPATCHED`, `DAILY_RISK_REPORT`, etc.).
- Looks up the target `StaffUser`. If `user.is_email_verified == True` and `user.email` is set,
  routes the alert via SMTP Email + In-App Push. Otherwise routes via `IN_APP_PUSH_ONLY`.
- NEVER invokes the Sparrow SMS or Aakash SMS gateway for alerts, reports, or RRT dispatches
  (Zero SMS gateway cost at 52,000+ national staff scale).
- Renders clean HTML email templates with Government of Nepal (MoHP / EDCD Teku) branding and
  Bikram Sambat (BS) + Gregorian (AD) Dual-Calendar dates (`२०८३ कार्तिक ९ | 2026-10-26`).
"""

from __future__ import annotations

import asyncio
import logging
import smtplib
from dataclasses import dataclass, field
from email.message import EmailMessage
from html import escape
from typing import Any, Literal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.bs_calendar import ad_to_bs_stamp
from app.core.config import get_settings
from app.db.models.staff_user import StaffUser

logger = logging.getLogger("nidaniq.notification_service")

SystemNotificationEventType = Literal[
    "SLA_BREACH",
    "RRT_DISPATCHED",
    "DAILY_RISK_REPORT",
    "ULV_FOCAL_OVERRIDE_APPROVED",
]

# Deterministic dev/test outboxes for automated verification
_DEV_EMAIL_OTP_OUTBOX: dict[str, str] = {}
_DEV_DISPATCHED_EMAILS: list[dict[str, Any]] = []


def get_dev_last_email_otp(user_id: str) -> str | None:
    """Return the last generated 6-digit Email verification OTP for `user_id` in dev/test mode."""
    return _DEV_EMAIL_OTP_OUTBOX.get(user_id)


def get_dispatched_email_outbox() -> list[dict[str, Any]]:
    """Return all HTML emails dispatched by NotificationService in the current process/test."""
    return list(_DEV_DISPATCHED_EMAILS)


def clear_notification_outbox() -> None:
    """Clear in-memory email outboxes (used by test fixtures)."""
    _DEV_EMAIL_OTP_OUTBOX.clear()
    _DEV_DISPATCHED_EMAILS.clear()


def render_nepal_gov_html_email(
    *,
    subject_en: str,
    subject_ne: str,
    recipient_name: str,
    recipient_role: str,
    palika_code: str,
    event_type: str,
    body_paragraphs_ne: list[str],
    body_paragraphs_en: list[str],
    telemetry_rows: list[tuple[str, str]] | None = None,
) -> str:
    """
    Render an official Government of Nepal (MoHP / EDCD Teku) HTML email template
    with Crimson & Royal Nepal Blue branding and Bikram Sambat (BS) dual-calendar dates.
    """
    stamp = ad_to_bs_stamp()
    rows_html = ""
    if telemetry_rows:
        tr_items = "".join(
            f'<tr><td style="padding:8px 12px;border-bottom:1px solid #E6E3DC;font-weight:600;color:#475569;">{escape(k)}</td>'
            f'<td style="padding:8px 12px;border-bottom:1px solid #E6E3DC;font-family:monospace;color:#0F172A;">{escape(v)}</td></tr>'
            for k, v in telemetry_rows
        )
        rows_html = (
            f'<table style="width:100%;border-collapse:collapse;margin:16px 0;background:#F7F6F2;border-radius:8px;">'
            f"{tr_items}</table>"
        )

    ne_html = "".join(
        f'<p style="margin:0 0 10px 0;font-size:15px;color:#1E2229;">{escape(p)}</p>'
        for p in body_paragraphs_ne
    )
    en_html = "".join(
        f'<p style="margin:0 0 10px 0;font-size:14px;color:#475569;">{escape(p)}</p>'
        for p in body_paragraphs_en
    )

    return f"""<!DOCTYPE html>
<html lang="ne">
<head>
  <meta charset="UTF-8" />
  <title>{escape(subject_en)}</title>
</head>
<body style="margin:0;padding:24px;background-color:#F7F6F2;font-family:'Noto Sans Devanagari','Kalimati',system-ui,sans-serif;color:#1E2229;">
  <div style="max-width:640px;margin:0 auto;background:#FFFFFF;border:1px solid #E5E2DC;border-radius:12px;overflow:hidden;">
    <div style="background:linear-gradient(135deg,#0F172A 0%,#1E3A8A 70%,#B91C1C 100%);color:#FFFFFF;padding:20px 24px;border-bottom:4px solid #D97706;">
      <div style="font-size:12px;letter-spacing:0.05em;text-transform:uppercase;color:#FDE68A;">
        नेपाल सरकार • स्वास्थ्य तथा जनसंख्या मन्त्रालय (MoHP / EDCD Teku)
      </div>
      <h2 style="margin:6px 0 2px 0;font-size:19px;">{escape(subject_ne)}</h2>
      <div style="font-size:13px;opacity:0.92;">{escape(subject_en)}</div>
      <div style="margin-top:8px;font-family:monospace;font-size:12px;color:#E2E8F0;">
        मिति (Bikram Sambat | AD): {escape(stamp.bs_ad_official_label)} • Palika: {escape(palika_code)}
      </div>
    </div>
    <div style="padding:24px;">
      <p style="margin:0 0 12px 0;font-weight:700;color:#1E3A8A;">
        नमस्कार {escape(recipient_name)} ({escape(recipient_role)}),
      </p>
      {ne_html}
      <hr style="border:none;border-top:1px solid #E5E2DC;margin:14px 0;" />
      {en_html}
      {rows_html}
      <div style="margin-top:18px;padding:12px;background:#ECFDF5;border-left:4px solid #10B981;border-radius:6px;font-size:12.5px;color:#065F46;">
        <strong>Zero-Cost Sovereign Alert Channel:</strong> Dispatched via IDMC Singha Durbar SMTP Relay &amp; In-App Push (Zero SMS Gateway Cost).
      </div>
    </div>
    <div style="background:#F1EFEA;padding:14px 24px;font-size:12px;color:#64748B;text-align:center;">
      NidanIQ Sovereign Vector Surveillance DPI • Event: {escape(event_type)} • {escape(stamp.bs_combined_label)} • Hotline: 1115
    </div>
  </div>
</body>
</html>"""


@dataclass
class NotificationService:
    """
    Asynchronous Notification Routing Engine for NidanIQ Nepal DPI.
    - Routes system alerts (`SLA_BREACH`, `RRT_DISPATCHED`, `DAILY_RISK_REPORT`) strictly via
      Email (when `user.is_email_verified == True`) + In-App Push.
    - Never uses Sparrow/Aakash SMS for alerts or reports.
    """

    in_app_push_feed: list[dict[str, Any]] = field(default_factory=list)

    async def send_email_verification_otp(
        self,
        *,
        user: StaffUser,
        target_email: str,
        otp_code: str,
    ) -> dict[str, Any]:
        """Dispatch a 6-digit Email verification OTP via SMTP (TTL 15 minutes)."""
        stamp = ad_to_bs_stamp()
        _DEV_EMAIL_OTP_OUTBOX[user.id] = otp_code

        subject_en = "NidanIQ MoHP/EDCD — Verify Your Official Email Address (OTP Inside)"
        subject_ne = "निदान-आईक्यू (NidanIQ) — तपाईंको आधिकारिक इमेल प्रमाणित गर्नुहोस्"
        html_body = render_nepal_gov_html_email(
            subject_en=subject_en,
            subject_ne=subject_ne,
            recipient_name=user.full_name_ne or user.full_name,
            recipient_role=user.role,
            palika_code=user.palika_code,
            event_type="EMAIL_OTP_VERIFICATION",
            body_paragraphs_ne=[
                f"तपाईंको निःशुल्क पालिका स्वास्थ्य सतर्कता (Zero-Cost Alerts) का लागि ६-अंकको इमेल भेरिफिकेसन कोड: {otp_code} हो।",
                "यो कोड १५ मिनेटसम्म मान्य रहनेछ।",
            ],
            body_paragraphs_en=[
                f"Your 6-digit verification code to link '{target_email}' for zero-cost MoHP/Palika notifications is: {otp_code}.",
                "This code expires in 15 minutes (900 seconds).",
            ],
            telemetry_rows=[
                ("Verification OTP Code", otp_code),
                ("Target Email", target_email),
                ("TTL Validity", "15 Minutes (900s)"),
                ("Bikram Sambat Date", stamp.bs_ad_official_label),
            ],
        )

        delivery_mode = await self._deliver_smtp_html_email(
            to_email=target_email,
            subject=subject_en,
            html_body=html_body,
            event_type="EMAIL_OTP_VERIFICATION",
            actor_id=user.id,
        )
        return {
            "channel": "SMTP_EMAIL_OTP",
            "delivery_mode": delivery_mode,
            "recipient_email": target_email,
            "sms_gateway_used": False,
            "bs_date": stamp.bs_combined_label,
            "bs_ad_official_label": stamp.bs_ad_official_label,
        }

    async def route_system_event(
        self,
        session: AsyncSession,
        *,
        target_user_id: str,
        event_type: SystemNotificationEventType,
        title_en: str,
        title_ne: str,
        summary_en: str,
        summary_ne: str,
        metadata: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """
        Intercept a system event (`SLA_BREACH`, `RRT_DISPATCHED`, `DAILY_RISK_REPORT`),
        look up the target `StaffUser`, and route via Email (ONLY if `user.is_email_verified == True`)
        + In-App Push. Strictly NEVER uses Sparrow/Aakash SMS.
        """
        stamp = ad_to_bs_stamp()
        user = (
            await session.execute(
                select(StaffUser).where(StaffUser.id == target_user_id)
            )
        ).scalar_one_or_none()

        push_item = {
            "user_id": target_user_id,
            "event_type": event_type,
            "title_en": title_en,
            "title_ne": title_ne,
            "summary_en": summary_en,
            "summary_ne": summary_ne,
            "metadata": metadata or {},
            "bs_date": stamp.bs_combined_label,
            "bs_ad_official_label": stamp.bs_ad_official_label,
        }
        self.in_app_push_feed.append(push_item)

        if user is None or not user.email or not user.is_email_verified:
            return {
                "event_type": event_type,
                "target_user_id": target_user_id,
                "routed_channels": ["IN_APP_PUSH"],
                "email_dispatched": False,
                "email_skip_reason": (
                    "USER_NOT_FOUND"
                    if user is None
                    else ("NO_EMAIL_LINKED" if not user.email else "EMAIL_NOT_VERIFIED")
                ),
                "sms_gateway_used": False,
                "sms_cost_npr": 0.0,
                "bs_date": stamp.bs_combined_label,
                "bs_ad_official_label": stamp.bs_ad_official_label,
            }

        telemetry_rows = [
            ("Event Type", event_type),
            ("Palika Code", user.palika_code),
            ("Bikram Sambat Date", stamp.bs_ad_official_label),
        ]
        for k, v in (metadata or {}).items():
            telemetry_rows.append((str(k), str(v)))

        html_body = render_nepal_gov_html_email(
            subject_en=f"[MoHP/EDCD {event_type}] {title_en}",
            subject_ne=f"[स्वास्थ्य सतर्कता — {event_type}] {title_ne}",
            recipient_name=user.full_name_ne or user.full_name,
            recipient_role=user.role,
            palika_code=user.palika_code,
            event_type=event_type,
            body_paragraphs_ne=[summary_ne],
            body_paragraphs_en=[summary_en],
            telemetry_rows=telemetry_rows,
        )

        delivery_mode = await self._deliver_smtp_html_email(
            to_email=user.email,
            subject=f"[MoHP/EDCD {event_type}] {title_en}",
            html_body=html_body,
            event_type=event_type,
            actor_id=user.id,
        )
        return {
            "event_type": event_type,
            "target_user_id": user.id,
            "recipient_email": user.email,
            "routed_channels": ["SMTP_EMAIL", "IN_APP_PUSH"],
            "email_dispatched": True,
            "delivery_mode": delivery_mode,
            "sms_gateway_used": False,
            "sms_cost_npr": 0.0,
            "bs_date": stamp.bs_combined_label,
            "bs_ad_official_label": stamp.bs_ad_official_label,
        }

    async def _deliver_smtp_html_email(
        self,
        *,
        to_email: str,
        subject: str,
        html_body: str,
        event_type: str,
        actor_id: str,
    ) -> str:
        """Send HTML email via configured SMTP relay (or record in deterministic outbox in dev/test)."""
        settings = get_settings()
        stamp = ad_to_bs_stamp()
        record = {
            "to_email": to_email,
            "from_email": settings.smtp_from_email,
            "subject": subject,
            "html_body": html_body,
            "event_type": event_type,
            "actor_id": actor_id,
            "smtp_host": settings.smtp_host,
            "smtp_port": settings.smtp_port,
            "sms_gateway_used": False,
            "bs_date": stamp.bs_combined_label,
            "bs_ad_official_label": stamp.bs_ad_official_label,
        }
        _DEV_DISPATCHED_EMAILS.append(record)

        if settings.env in {"development", "test"} or not settings.smtp_pass:
            logger.info(
                "[ZERO-COST SMTP MOCK -> %s | %s] %s",
                to_email,
                event_type,
                subject,
            )
            return f"smtp_mock ({settings.smtp_host}:{settings.smtp_port})"

        msg = EmailMessage()
        msg["Subject"] = subject
        msg["From"] = settings.smtp_from_email
        msg["To"] = to_email
        msg.set_content(subject)
        msg.add_alternative(html_body, subtype="html")

        def _send_sync() -> None:
            with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=8) as server:
                server.starttls()
                if settings.smtp_user and settings.smtp_pass:
                    server.login(settings.smtp_user, settings.smtp_pass)
                server.send_message(msg)

        await asyncio.to_thread(_send_sync)
        return f"smtp_live ({settings.smtp_host}:{settings.smtp_port})"


_notification_service = NotificationService()


def get_notification_service() -> NotificationService:
    """Return singleton NotificationService."""
    return _notification_service
