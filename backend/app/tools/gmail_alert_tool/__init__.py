"""Gmail / SMTP TLS Automated Emergency Alert Dispatch Tool."""

from app.tools.gmail_alert_tool.client import (
    EmailAlertClient,
    EmailDeliveryReceipt,
    get_email_alert_client,
)
from app.tools.gmail_alert_tool.exceptions import EmailDispatchException

__all__ = [
    "EmailAlertClient",
    "EmailDeliveryReceipt",
    "EmailDispatchException",
    "get_email_alert_client",
]
