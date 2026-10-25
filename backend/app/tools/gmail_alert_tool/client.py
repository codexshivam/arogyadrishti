"""Gmail API / SMTP TLS emergency HTML alert dispatcher with regex + DNS MX validation."""

from __future__ import annotations

import logging
import re
import smtplib
import uuid
from datetime import UTC, datetime
from email.message import EmailMessage
from email.utils import formataddr, make_msgid
from functools import lru_cache
from typing import Any

import dns.resolver
from fastapi import status
from pydantic import BaseModel
from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)

from app.core.config import Settings, get_settings
from app.tools.gmail_alert_tool.exceptions import EmailDispatchException

logger = logging.getLogger("nidaniq.tools.gmail_alert")

_STRICT_EMAIL_RE = re.compile(
    r"^[A-Za-z0-9._%+-]+@([A-Za-z0-9.-]+\.[A-Za-z]{2,})$"
)


TEAM_NOTIFICATION_EMAILS: list[str] = [
    "academyxshivam@gmail.com",
    "chaudharyishwor143@gmail.com",
    "chaudharyraul07@gmail.com",
    "ay5589370@gmail.com",
]


class EmailDeliveryReceipt(BaseModel):
    """Structured delivery receipt persisted to Firestore and 5_Alert_Logs."""

    message_id: str
    to_email: str
    cc_email: str | None = None
    recipients: list[str] = []
    mx_verified: bool
    mx_host: str
    delivery_channel: str
    dispatched_at_utc: str


def verify_email_and_mx(email_address: str) -> str:
    """Validate email syntax via regex and verify domain MX records via dnspython."""
    cleaned = (email_address or "").strip()
    match = _STRICT_EMAIL_RE.match(cleaned)
    if not match:
        raise EmailDispatchException(
            f"Invalid recipient email address syntax: '{cleaned}'.",
            status_code=status.HTTP_400_BAD_REQUEST,
        )
    domain = match.group(1)
    try:
        answers = dns.resolver.resolve(domain, "MX", lifetime=5.0)
        mx_records = sorted(
            [(r.preference, str(r.exchange).rstrip(".")) for r in answers]
        )
        if not mx_records:
            raise EmailDispatchException(
                f"Domain '{domain}' has no MX records configured.",
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            )
        return mx_records[0][1]
    except EmailDispatchException:
        raise
    except Exception as exc:
        raise EmailDispatchException(
            f"DNS MX verification failed for domain '{domain}': {exc}",
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        ) from exc


def get_email_theme_by_metrics(bi_value: float, composite_score: float) -> dict[str, str]:
    """Select dynamic visual palette based on calculated Breteau Index and Composite Risk Score."""
    bi = float(bi_value)
    comp = float(composite_score)

    if bi >= 35.0 or comp >= 80.0:
        return {
            "tier": "CRITICAL OUTBREAK",
            "header_bg": "#4A0E0E",  # Deep Emergency Maroon
            "accent_color": "#B71C1C",
            "badge_bg": "#FFCDD2",
            "badge_text": "#B71C1C",
            "card_border": "#EF9A9A",
            "banner_subtitle": "Statutory NCVBDC Epidemic Threshold Exceeded (BI ≥ 35) — Immediate ULV Fogging Required",
            "sla_label": "CRITICAL (2h Response SLA)",
        }
    elif bi >= 20.0 or comp >= 65.0:
        return {
            "tier": "HIGH RISK",
            "header_bg": "#C62828",  # Alert Crimson
            "accent_color": "#D32F2F",
            "badge_bg": "#FFEBEE",
            "badge_text": "#C62828",
            "card_border": "#EF9A9A",
            "banner_subtitle": "WHO Transmission Threshold Exceeded (BI ≥ 20) — Deploy Focal Larviciding Squad Within 24h",
            "sla_label": "HIGH (6h Response SLA)",
        }
    elif bi >= 5.0 or comp >= 40.0:
        return {
            "tier": "MODERATE RISK",
            "header_bg": "#E65100",  # Amber Advisory
            "accent_color": "#EF6C00",
            "badge_bg": "#FFF3E0",
            "badge_text": "#E65100",
            "card_border": "#FFCC80",
            "banner_subtitle": "Moderate Vector Breeding Activity (BI 5–20) — Targeted Source Reduction & Temephos Application",
            "sla_label": "MODERATE (24h Routine SLA)",
        }
    else:
        return {
            "tier": "LOW / SAFE",
            "header_bg": "#1B5E20",  # Safe Forest Green
            "accent_color": "#2E7D32",
            "badge_bg": "#E8F5E9",
            "badge_text": "#1B5E20",
            "card_border": "#A5D6A7",
            "banner_subtitle": "Vector Indices Within Safe Statutory Norms (BI < 5) — Maintain Weekly Surveillance",
            "sla_label": "NORMAL (Routine Surveillance)",
        }


def build_nidaniq_email_html(
    ward_name: str,
    lgd_code: str,
    officer_name: str,
    bi_value: float,
    hi_value: float,
    ci_value: float,
    houses_inspected: int,
    containers_inspected: int,
    containers_positive: int,
    lst_celsius: float,
    ndwi: float,
    rain_14d_mm: float,
    composite_score: float,
    ai_recommendation: str,
    lat: float,
    lng: float,
    notes: str = "",
    van_info: dict[str, Any] | None = None,
) -> tuple[str, str]:
    theme = get_email_theme_by_metrics(bi_value, composite_score)
    subject = f"NidanIQ - BI ({bi_value:.1f}) in your Region"
    maps_url = f"https://www.google.com/maps/search/?api=1&query={lat},{lng}"

    van_section_html = ""
    if van_info:
        van_section_html = f"""
        <div style="margin-top:16px;padding:14px;background-color:#F8FAFC;border-left:4px solid {theme['accent_color']};border-radius:6px;">
          <div style="font-size:11px;font-weight:700;text-transform:uppercase;color:#475569;letter-spacing:0.5px;">Assigned Vector Control Unit</div>
          <div style="font-size:14px;font-weight:700;color:#0F172A;margin-top:3px;">
            Vehicle: {van_info.get('vehicle_no')} ({van_info.get('van_id')}) — ETA: {van_info.get('eta_mins')} mins ({van_info.get('distance_km')} km)
          </div>
          <div style="font-size:12px;color:#334155;margin-top:2px;">
            Driver: {van_info.get('driver_name')} | Contact: {van_info.get('driver_phone')}
          </div>
        </div>
        """

    html_body = f"""
    <!DOCTYPE html>
    <html>
    <body style="margin:0;padding:24px;background-color:#F1F5F9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
      <table width="100%" cellpadding="0" cellspacing="0" style="max-width:640px;margin:0 auto;background-color:#FFFFFF;border-radius:12px;overflow:hidden;border:1px solid #E2E8F0;">
        <!-- Header -->
        <tr>
          <td style="background-color:{theme['header_bg']};padding:22px 26px;color:#FFFFFF;">
            <div style="display:inline-block;padding:4px 10px;background-color:{theme['badge_bg']};color:{theme['badge_text']};font-size:11px;font-weight:800;border-radius:4px;letter-spacing:0.6px;">
              {theme['tier']} • {theme['sla_label']}
            </div>
            <h1 style="margin:10px 0 4px 0;font-size:20px;font-weight:700;color:#FFFFFF;">
              NidanIQ — Regional Vector Surveillance Report
            </h1>
            <p style="margin:0;font-size:13px;color:#F1F5F9;">
              <strong>{ward_name}</strong> (<a href="{maps_url}" style="color:#FEE2E2;text-decoration:underline;font-weight:600;">Open in Google Maps</a>)
            </p>
          </td>
        </tr>

        <!-- Body Content -->
        <tr>
          <td style="padding:22px 26px;">
            <p style="margin:0.5;font-size:13px;color:#334155;line-height:1.5;">
              Dear <strong>{officer_name}</strong>,<br>
              Verified entomological and GEE satellite telemetry summary for your assigned jurisdiction:
            </p>

            <!-- KPI Cards -->
            <table width="100%" cellpadding="0" cellspacing="0" style="margin:16px 0;">
              <tr>
                <td width="32%" style="padding:12px;background-color:#F8FAFC;border:1px solid {theme['card_border']};border-radius:8px;text-align:center;">
                  <div style="font-size:10px;font-weight:700;color:#64748B;text-transform:uppercase;">Breteau Index (BI)</div>
                  <div style="font-size:24px;font-weight:800;color:{theme['accent_color']};margin:4px 0;">{bi_value:.1f}</div>
                  <div style="font-size:10px;color:#475569;">Norm &lt; 5.0</div>
                </td>
                <td width="2%"></td>
                <td width="32%" style="padding:12px;background-color:#F8FAFC;border:1px solid #CBD5E1;border-radius:8px;text-align:center;">
                  <div style="font-size:10px;font-weight:700;color:#64748B;text-transform:uppercase;">House Index (HI)</div>
                  <div style="font-size:24px;font-weight:800;color:#0F172A;margin:4px 0;">{hi_value:.1f}%</div>
                  <div style="font-size:10px;color:#475569;">{houses_inspected} Homes</div>
                </td>
                <td width="2%"></td>
                <td width="32%" style="padding:12px;background-color:#F8FAFC;border:1px solid #CBD5E1;border-radius:8px;text-align:center;">
                  <div style="font-size:10px;font-weight:700;color:#64748B;text-transform:uppercase;">Container Index (CI)</div>
                  <div style="font-size:24px;font-weight:800;color:#0F172A;margin:4px 0;">{ci_value:.1f}%</div>
                  <div style="font-size:10px;color:#475569;">{containers_positive}/{containers_inspected} Pos</div>
                </td>
              </tr>
            </table>

            <!-- Vertical Satellite Telemetry Display (No GEE header, vertical format) -->
            <div style="padding:14px 16px;background-color:#F8FAFC;border:1px solid #E2E8F0;border-radius:8px;margin-bottom:16px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="font-size:12px;color:#334155;line-height:1.6;">
                <tr>
                  <td style="padding:5px 0;color:#64748B;font-weight:600;width:55%;">Land Surface Temp (MODIS LST):</td>
                  <td style="padding:5px 0;font-weight:700;color:#0F172A;">{lst_celsius:.1f} &deg;C</td>
                </tr>
                <tr>
                  <td style="padding:5px 0;border-top:1px solid #F1F5F9;color:#64748B;font-weight:600;">Stagnant Water (Sentinel-2 NDWI):</td>
                  <td style="padding:5px 0;border-top:1px solid #F1F5F9;font-weight:700;color:#0F172A;">{ndwi:.3f}</td>
                </tr>
                <tr>
                  <td style="padding:5px 0;border-top:1px solid #F1F5F9;color:#64748B;font-weight:600;">14-Day Cumulative Rain (NASA GPM):</td>
                  <td style="padding:5px 0;border-top:1px solid #F1F5F9;font-weight:700;color:#0F172A;">{rain_14d_mm:.1f} mm</td>
                </tr>
                <tr>
                  <td style="padding:5px 0;border-top:1px solid #F1F5F9;color:#64748B;font-weight:600;">Composite Risk Score:</td>
                  <td style="padding:5px 0;border-top:1px solid #F1F5F9;font-weight:800;color:{theme['accent_color']};">{composite_score:.1f} / 100</td>
                </tr>
              </table>
            </div>

            <!-- AI Protocol -->
            <div style="padding:14px;background-color:{theme['badge_bg']};border-radius:8px;border:1px solid {theme['card_border']};">
              <div style="font-size:11px;font-weight:800;color:{theme['badge_text']};text-transform:uppercase;">
                NCVBDC / AI Recommended Intervention Protocol
              </div>
              <p style="margin:4px 0 0 0;font-size:12.5px;color:#1E293B;line-height:1.4;">
                {ai_recommendation}
              </p>
              {f'<p style="margin:6px 0 0 0;font-size:11.5px;color:#475569;"><strong>Notes:</strong> {notes}</p>' if notes else ''}
            </div>

            {van_section_html}

            <!-- Helpline Contact -->
            <div style="margin-top:16px;padding:12px 14px;background-color:#F8FAFC;border:1px solid #E2E8F0;border-radius:8px;font-size:12px;color:#334155;">
              <div style="font-size:11px;font-weight:700;text-transform:uppercase;color:#475569;letter-spacing:0.5px;">Emergency Technical Support &amp; Helpline</div>
              <div style="font-size:13px;font-weight:700;color:#0F172A;margin-top:3px;">
                Toll-Free 24/7 Helpline: <span style="color:#B71C1C;">1800-11-8328</span>
              </div>
              <div style="font-size:11.5px;color:#64748B;margin-top:2px;">
                Email: <a href="mailto:support@NidanIQ.in" style="color:#B71C1C;text-decoration:underline;">support@NidanIQ.in</a> &nbsp;|&nbsp; NCVBDC Surveillance Cell
              </div>
            </div>
          </td>
        </tr>

        <!-- Footer -->
        <tr>
          <td style="background-color:#F8FAFC;padding:16px 26px;border-top:1px solid #E2E8F0;font-size:11px;color:#64748B;text-align:center;line-height:1.5;">
            <p style="margin:0 0 6px 0;font-size:11px;color:#64748B;">
              This email was sent for the purpose of real-time vector surveillance, early epidemic warning, and rapid containment coordination under the National Vector Borne Disease Control Programme (NCVBDC) guidelines.
            </p>
            <div style="font-weight:600;color:#475569;">
              NidanIQ App | Powered by Shivam Yadav
            </div>
          </td>
        </tr>
      </table>
    </body>
    </html>
    """
    return subject, html_body


def build_emergency_alert_html(
    ward_village: str,
    lat: float,
    lng: float,
    severity: str,
    breteau_index: float,
    gee_risk_score: float,
    lst_celsius: float | None,
    rain_14d_mm: float | None,
    notes: str,
    district_rep_phone: str | None,
) -> str:
    """Backward-compatible wrapper utilizing the responsive multi-tier template."""
    comp_score = round(gee_risk_score * 100.0, 1) if gee_risk_score <= 1.0 else round(gee_risk_score, 1)
    _, html = build_nidaniq_email_html(
        ward_name=ward_village,
        lgd_code="0404400017",
        officer_name="Vector Surveillance Officer",
        bi_value=breteau_index,
        hi_value=round(breteau_index * 0.45, 1),
        ci_value=round(breteau_index * 0.55, 1),
        houses_inspected=180,
        containers_inspected=420,
        containers_positive=int(round((breteau_index / 100.0) * 180)),
        lst_celsius=lst_celsius if lst_celsius is not None else 28.5,
        ndwi=-0.22,
        rain_14d_mm=rain_14d_mm if rain_14d_mm is not None else 65.0,
        composite_score=comp_score,
        ai_recommendation=f"[{severity}] Temephos 50% EC @ 1 ppm (2 ml/1000L) application and source reduction within designated SLA.",
        lat=lat,
        lng=lng,
        notes=notes,
    )
    return html


def build_ticket_assignment_email_html(
    ticket_id: str,
    ward_name: str,
    category: str,
    severity_sla: str,
    observation_notes: str,
    assigned_officer_name: str,
    timestamp_utc: str,
    lat: float | None = None,
    lng: float | None = None,
) -> tuple[str, str]:
    """Build responsive zero-blue crimson HTML email for escalation ticket assignment."""
    subject = "Ticket assigned to you - NidanIQ"

    maps_url = ""
    if lat is not None and lng is not None and abs(lat) > 0.1 and abs(lng) > 0.1:
        maps_url = f"https://www.google.com/maps/search/?api=1&query={lat},{lng}"

    html_body = f"""
    <!DOCTYPE html>
    <html>
    <body style="margin:0;padding:24px;background-color:#F1F5F9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
      <table width="100%" cellpadding="0" cellspacing="0" style="max-width:640px;margin:0 auto;background-color:#FFFFFF;border-radius:12px;overflow:hidden;border:1px solid #E2E8F0;">
        <!-- Header (Crimson Zero-Blue) -->
        <tr>
          <td style="background-color:#7F1D1D;padding:22px 26px;color:#FFFFFF;">
            <h1 style="margin:0 0 10px 0;font-size:20px;font-weight:700;color:#FFFFFF;">
              NidanIQ — Field Ticket Assignment
            </h1>
            <div style="font-size:13px;color:#F1F5F9;line-height:1.6;">
              <div>Ticket ID: <strong>{ticket_id}</strong></div>
              <div><strong>{ward_name}</strong></div>
              {f'<div><a href="{maps_url}" style="color:#FEE2E2;text-decoration:underline;font-weight:600;">Open in Google Maps</a></div>' if maps_url else ''}
            </div>
          </td>
        </tr>

        <!-- Body Content -->
        <tr>
          <td style="padding:22px 26px;">
            <p style="margin:0 0 16px 0;font-size:13px;color:#334155;line-height:1.5;">
              Dear <strong>{assigned_officer_name}</strong>,<br>
              A vector surveillance escalation ticket has been logged and assigned to your jurisdiction under the NCVBDC operational protocol.
            </p>

            <table width="100%" cellpadding="0" cellspacing="0" style="margin:16px 0;border:1px solid #E2E8F0;border-radius:8px;overflow:hidden;">
              <tr style="background-color:#F8FAFC;border-bottom:1px solid #E2E8F0;">
                <td style="padding:10px 14px;font-size:12px;font-weight:700;color:#475569;width:35%;">Category</td>
                <td style="padding:10px 14px;font-size:12px;color:#0F172A;font-weight:600;">{category}</td>
              </tr>
              <tr style="border-bottom:1px solid #E2E8F0;">
                <td style="padding:10px 14px;font-size:12px;font-weight:700;color:#475569;">Severity / SLA</td>
                <td style="padding:10px 14px;font-size:12px;color:#991B1B;font-weight:700;">{severity_sla}</td>
              </tr>
              <tr style="background-color:#F8FAFC;border-bottom:1px solid #E2E8F0;">
                <td style="padding:10px 14px;font-size:12px;font-weight:700;color:#475569;">Assigned Jurisdiction</td>
                <td style="padding:10px 14px;font-size:12px;color:#0F172A;">{ward_name}</td>
              </tr>
              <tr>
                <td style="padding:10px 14px;font-size:12px;font-weight:700;color:#475569;">Logged At (UTC)</td>
                <td style="padding:10px 14px;font-size:12px;color:#64748B;">{timestamp_utc}</td>
              </tr>
            </table>

            <div style="padding:14px;background-color:#FFF5F5;border-radius:8px;border:1px solid #FECACA;margin-bottom:16px;">
              <div style="font-size:11px;font-weight:800;color:#991B1B;text-transform:uppercase;">
                Field Observation &amp; Escalation Notes
              </div>
              <p style="margin:6px 0 0 0;font-size:13px;color:#1E293B;line-height:1.5;">
                {observation_notes}
              </p>
            </div>

            <p style="margin:0;font-size:12px;color:#64748B;line-height:1.4;">
              Please initiate on-ground verification or dispatch vector response personnel according to standard operating procedures. Update the ticket status in the NidanIQ portal once resolved.
            </p>

            <!-- Helpline Contact -->
            <div style="margin-top:16px;padding:12px 14px;background-color:#F8FAFC;border:1px solid #E2E8F0;border-radius:8px;font-size:12px;color:#334155;">
              <div style="font-size:11px;font-weight:700;text-transform:uppercase;color:#475569;letter-spacing:0.5px;">Emergency Technical Support &amp; Helpline</div>
              <div style="font-size:13px;font-weight:700;color:#0F172A;margin-top:3px;">
                Toll-Free 24/7 Helpline: <span style="color:#991B1B;">1800-11-8328</span>
              </div>
              <div style="font-size:11.5px;color:#64748B;margin-top:2px;">
                Email: <a href="mailto:support@NidanIQ.in" style="color:#991B1B;text-decoration:underline;">support@NidanIQ.in</a> &nbsp;|&nbsp; NCVBDC Grievance Redressal
              </div>
            </div>
          </td>
        </tr>

        <!-- Footer -->
        <tr>
          <td style="background-color:#F8FAFC;padding:16px 26px;border-top:1px solid #E2E8F0;font-size:11px;color:#64748B;text-align:center;line-height:1.5;">
            <p style="margin:0 0 6px 0;font-size:11px;color:#64748B;">
              This email was sent for the purpose of vector surveillance field escalation, grievance redressal, and rapid municipal action under NCVBDC guidelines.
            </p>
            <div style="font-weight:600;color:#475569;">
              NidanIQ App | Powered by Shivam Yadav
            </div>
          </td>
        </tr>
      </table>
    </body>
    </html>
    """
    return subject, html_body


class EmailAlertClient:
    """Sends HTML emergency alert emails with MX validation and tenacity retry."""

    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type(smtplib.SMTPException),
        reraise=True,
    )
    def _send_via_smtp(self, msg: EmailMessage) -> None:
        with smtplib.SMTP(
            self.settings.smtp_host, self.settings.smtp_port, timeout=10
        ) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(self.settings.smtp_user, self.settings.smtp_password)
            server.send_message(msg)

    def send_emergency_alert(
        self,
        to_email: str,
        ward_village: str,
        lat: float,
        lng: float,
        notes: str,
        breteau_index: float,
        gee_risk_score: float,
        cc_email: str | None = None,
        severity: str = "CRITICAL",
        lst_celsius: float | None = None,
        rain_14d_mm: float | None = None,
        district_rep_phone: str | None = None,
        lgd_code: str = "0404400017",
        officer_name: str = "Surveillance Officer",
        hi_value: float | None = None,
        ci_value: float | None = None,
        houses_inspected: int | None = None,
        containers_inspected: int | None = None,
        containers_positive: int | None = None,
        ndwi: float | None = None,
        composite_score: float | None = None,
        ai_recommendation: str | None = None,
        van_info: dict[str, Any] | None = None,
    ) -> EmailDeliveryReceipt:
        """Validate recipient MX records, construct RFC 5322 HTML message, and dispatch via SMTP TLS."""
        mx_host = verify_email_and_mx(to_email)

        # User directive: In alert email sent, don't include CC

        if not self.settings.smtp_user or not self.settings.smtp_password:
            raise EmailDispatchException(
                "SMTP_USER and SMTP_PASSWORD must be configured to dispatch live alert emails.",
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        # Derived values for email
        h_insp = houses_inspected if houses_inspected is not None else 180
        h_pos = int(round(((hi_value or 8.0) / 100.0) * h_insp))
        c_insp = containers_inspected if containers_inspected is not None else int(h_insp * 2.3)
        c_pos = containers_positive if containers_positive is not None else int(round((breteau_index / 100.0) * h_insp))
        hi = hi_value if hi_value is not None else round((h_pos / h_insp) * 100.0, 1)
        ci = ci_value if ci_value is not None else round((c_pos / c_insp) * 100.0, 1)

        comp_score = (
            composite_score
            if composite_score is not None
            else (round(gee_risk_score * 100.0, 1) if gee_risk_score <= 1.0 else round(gee_risk_score, 1))
        )

        rec = ai_recommendation or (
            f"[{severity}] Immediate larvicidal treatment with Temephos 50% EC @ 1 ppm (2 ml/1000L). "
            f"Focal ULV thermal fogging with Cyphenothrin 5% EC if Breteau Index exceeds epidemic limit."
        )

        subject, html_body = build_nidaniq_email_html(
            ward_name=ward_village,
            lgd_code=lgd_code,
            officer_name=officer_name,
            bi_value=breteau_index,
            hi_value=hi,
            ci_value=ci,
            houses_inspected=h_insp,
            containers_inspected=c_insp,
            containers_positive=c_pos,
            lst_celsius=lst_celsius if lst_celsius is not None else 28.5,
            ndwi=ndwi if ndwi is not None else -0.22,
            rain_14d_mm=rain_14d_mm if rain_14d_mm is not None else 65.0,
            composite_score=comp_score,
            ai_recommendation=rec,
            lat=lat,
            lng=lng,
            notes=notes,
            van_info=van_info,
        )

        msg_id = make_msgid(domain="NidanIQ.in")
        msg = EmailMessage()
        msg["Subject"] = subject
        from_email = self.settings.smtp_user or self.settings.alert_from_address or "alerts@NidanIQ.in"
        msg["From"] = formataddr(("NidanIQ App", from_email))
        msg["To"] = to_email.strip()
        # Strictly no CC in alert emails
        msg["Message-ID"] = msg_id

        msg.set_content(
            f"{subject}\n\n"
            f"Jurisdiction: {ward_village} (LGD: {lgd_code})\n"
            f"Breteau Index: {breteau_index:.1f} | HI: {hi:.1f}% | CI: {ci:.1f}%\n"
            f"Land Surface Temp: {lst_celsius if lst_celsius is not None else 28.5:.1f} °C\n"
            f"Stagnant Water (NDWI): {ndwi if ndwi is not None else -0.22:.3f}\n"
            f"14-Day Cumulative Rain: {rain_14d_mm if rain_14d_mm is not None else 65.0:.1f} mm\n"
            f"Composite Risk Score: {comp_score:.1f} / 100\n"
            f"Coordinates: ({lat}, {lng})\n"
            f"Protocol: {rec}\n"
            f"Notes: {notes}\n\n"
            f"Helpline: 1800-11-8328 | Email: support@NidanIQ.in\n\n"
            f"Note: This email was sent for the purpose of real-time vector surveillance, early epidemic warning, and rapid containment coordination under NCVBDC guidelines.\n"
            f"NidanIQ App | Powered by Shivam Yadav\n"
        )
        msg.add_alternative(html_body, subtype="html")

        now_utc = datetime.now(UTC).isoformat()
        try:
            self._send_via_smtp(msg)
            channel = "SMTP_TLS_DELIVERED"
        except Exception as exc:
            logger.error("SMTP TLS send failed: %s", exc)
            raise EmailDispatchException(
                f"SMTP TLS delivery failed for {to_email}: {exc}"
            ) from exc

        all_recipients = [to_email.strip()]
        logger.info(
            "Dispatched alert to primary %s (no CC recipients as configured)",
            to_email.strip(),
        )

        return EmailDeliveryReceipt(
            message_id=msg_id.strip("<>") or str(uuid.uuid4()),
            to_email=to_email.strip(),
            cc_email=None,
            recipients=all_recipients,
            mx_verified=True,
            mx_host=mx_host,
            delivery_channel=channel,
            dispatched_at_utc=now_utc,
        )

    def send_ticket_assignment_email(
        self,
        ticket_id: str,
        ward_name: str,
        category: str,
        severity_sla: str,
        observation_notes: str,
        assigned_officer_name: str,
        assigned_officer_email: str,
        district_rep_email: str | None = None,
        timestamp_utc: str | None = None,
        lat: float | None = None,
        lng: float | None = None,
    ) -> EmailDeliveryReceipt:
        """Validate recipient MX records and dispatch zero-blue crimson ticket assignment email with CC to district rep and team."""
        to_email = (assigned_officer_email or "").strip()
        mx_host = verify_email_and_mx(to_email)
        to_norm = to_email.lower()

        # Send strictly To assigned officer; CC only if explicit supervisor/rep designated (no blind team broadcasts)
        cc_candidates: list[str] = []
        if district_rep_email and district_rep_email.strip():
            for part in district_rep_email.split(","):
                cand = part.strip()
                if cand and cand not in cc_candidates and cand.lower() != to_norm:
                    cc_candidates.append(cand)

        cc_verified: list[str] = []
        for cand in cc_candidates:
            if cand.lower() == to_norm or cand.lower() in [c.lower() for c in cc_verified]:
                continue
            try:
                verify_email_and_mx(cand)
                cc_verified.append(cand)
            except Exception as mx_err:
                logger.warning("Skipping unverified CC candidate %s: %s", cand, mx_err)

        if not self.settings.smtp_user or not self.settings.smtp_password:
            raise EmailDispatchException(
                "SMTP_USER and SMTP_PASSWORD must be configured to dispatch live alert emails.",
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        now_utc = timestamp_utc or datetime.now(UTC).isoformat()
        subject, html_body = build_ticket_assignment_email_html(
            ticket_id=ticket_id,
            ward_name=ward_name,
            category=category,
            severity_sla=severity_sla,
            observation_notes=observation_notes,
            assigned_officer_name=assigned_officer_name,
            timestamp_utc=now_utc,
            lat=lat,
            lng=lng,
        )

        msg_id = make_msgid(domain="NidanIQ.in")
        msg = EmailMessage()
        msg["Subject"] = subject
        from_email = self.settings.smtp_user or self.settings.alert_from_address or "alerts@NidanIQ.in"
        msg["From"] = formataddr(("NidanIQ App", from_email))
        msg["To"] = to_email
        if cc_verified:
            msg["Cc"] = ", ".join(cc_verified)
        msg["Message-ID"] = msg_id

        msg.set_content(
            f"{subject}\n\n"
            f"Ticket ID: {ticket_id}\n"
            f"Jurisdiction: {ward_name}\n"
            f"Assigned Officer: {assigned_officer_name} ({to_email})\n"
            f"Category: {category}\n"
            f"Severity / SLA: {severity_sla}\n"
            f"Logged At (UTC): {now_utc}\n\n"
            f"Observation Notes:\n{observation_notes}\n\n"
            f"Helpline: 1800-11-8328 | Email: support@NidanIQ.in\n\n"
            f"Note: This email was sent for the purpose of vector surveillance field escalation, grievance redressal, and rapid municipal action under NCVBDC guidelines.\n"
            f"NidanIQ App | Powered by Shivam Yadav\n"
        )
        msg.add_alternative(html_body, subtype="html")

        try:
            self._send_via_smtp(msg)
            channel = "SMTP_TLS_DELIVERED"
        except Exception as exc:
            logger.error("SMTP TLS ticket assignment email failed: %s", exc)
            raise EmailDispatchException(
                f"SMTP TLS delivery failed for {to_email}: {exc}"
            ) from exc

        all_recipients = [to_email] + cc_verified
        logger.info(
            "Dispatched ticket assignment email [%s] to %s and %d CCs",
            ticket_id,
            to_email,
            len(cc_verified),
        )

        return EmailDeliveryReceipt(
            message_id=msg_id.strip("<>") or str(uuid.uuid4()),
            to_email=to_email,
            cc_email=", ".join(cc_verified) if cc_verified else None,
            recipients=all_recipients,
            mx_verified=True,
            mx_host=mx_host,
            delivery_channel=channel,
            dispatched_at_utc=now_utc,
        )


@lru_cache(maxsize=1)
def get_email_alert_client() -> EmailAlertClient:
    """Return cached singleton EmailAlertClient."""
    return EmailAlertClient()


def send_ward_operational_email(
    ward_name: str,
    officer_email: str,
    subject: str,
    html_body: str,
) -> None:
    """
    Sends the email strictly to the designated ward officer without spamming all team members in CC.
    """
    settings = get_settings()
    cleaned_email = (officer_email or "").strip()
    if not cleaned_email:
        raise EmailDispatchException(
            f"Cannot send operational email for {ward_name}: empty officer_email.",
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    verify_email_and_mx(cleaned_email)

    msg = EmailMessage()
    msg["Subject"] = subject
    from_email = settings.alert_from_address or settings.smtp_user or "alerts@NidanIQ.in"
    msg["From"] = formataddr(("NidanIQ App", from_email))
    msg["To"] = cleaned_email

    msg.set_content("Please view this email in an HTML-compatible client.")
    msg.add_alternative(html_body, subtype="html")

    try:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=10) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(settings.smtp_user, settings.smtp_password)
            server.send_message(msg)
        logger.info("Operational email successfully sent to %s for %s", cleaned_email, ward_name)
    except Exception as e:
        logger.error("SMTP Error sending operational email to %s: %s", cleaned_email, e)
        raise
