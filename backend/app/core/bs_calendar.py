"""Bikram Sambat (BS) <-> Gregorian (AD) UTC+05:45 (Asia/Kathmandu) dual-date converter and Devanagari formatter."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta, timezone

import nepali_datetime

# Nepal Standard Time (NPT) is strictly UTC+05:45
NPT_TZ = timezone(timedelta(hours=5, minutes=45), name="Asia/Kathmandu")

_NEPALI_DIGITS = str.maketrans("0123456789", "०१२३४५६७८९")

_BS_MONTHS_DEVA: dict[int, str] = {
    1: "बैशाख",
    2: "जेठ",
    3: "असार",
    4: "श्रावण",
    5: "भाद्र",
    6: "आश्विन",
    7: "कार्तिक",
    8: "मंसिर",
    9: "पुष",
    10: "माघ",
    11: "फाल्गुन",
    12: "चैत्र",
}

_BS_MONTHS_ROMAN: dict[int, str] = {
    1: "Baisakh",
    2: "Jestha",
    3: "Ashadh",
    4: "Shrawan",
    5: "Bhadra",
    6: "Ashwin",
    7: "Kartik",
    8: "Mangsir",
    9: "Poush",
    10: "Magh",
    11: "Falgun",
    12: "Chaitra",
}


def to_devanagari_digits(value: str | int) -> str:
    """Convert ASCII numerals (0-9) into Nepali Devanagari numerals (०-९)."""
    return str(value).translate(_NEPALI_DIGITS)


@dataclass(frozen=True)
class DualDateStamp:
    """Statutory Government of Nepal dual-calendar timestamp representation."""

    timestamp_utc: str
    timestamp_npt: str
    bs_date_iso: str
    bs_date_devanagari: str
    bs_combined_label: str
    ad_date_iso: str = ""
    bs_ad_official_label: str = ""

    @property
    def bs_year(self) -> int:
        """Return the 4-digit Bikram Sambat year (e.g., 2083)."""
        return int(self.bs_date_iso[:4])

    def to_dict(self) -> dict[str, str]:
        return {
            "timestamp_utc": self.timestamp_utc,
            "timestamp_npt": self.timestamp_npt,
            "ad_date_iso": self.ad_date_iso,
            "bs_date_iso": self.bs_date_iso,
            "bs_date_devanagari": self.bs_date_devanagari,
            "bs_combined_label": self.bs_combined_label,
            "bs_ad_official_label": self.bs_ad_official_label,
        }


def ad_to_bs_stamp(dt: datetime | None = None) -> DualDateStamp:
    """Convert a UTC or timezone-aware datetime to Nepal Standard Time (UTC+05:45) and Bikram Sambat (BS)."""
    if dt is None:
        dt_utc = datetime.now(UTC)
    elif dt.tzinfo is None:
        dt_utc = dt.replace(tzinfo=UTC)
    else:
        dt_utc = dt.astimezone(UTC)

    dt_npt = dt_utc.astimezone(NPT_TZ)
    ad_iso = dt_npt.date().isoformat()
    bs_date = nepali_datetime.date.from_datetime_date(dt_npt.date())

    bs_iso = f"{bs_date.year:04d}-{bs_date.month:02d}-{bs_date.day:02d} BS"
    month_deva = _BS_MONTHS_DEVA.get(bs_date.month, "")
    year_deva = to_devanagari_digits(bs_date.year)
    day_deva = to_devanagari_digits(bs_date.day)
    bs_deva = f"{year_deva} {month_deva} {day_deva}"
    combined = f"{bs_iso} | {bs_deva}"
    bs_ad_official = f"{bs_deva} | {ad_iso}"

    return DualDateStamp(
        timestamp_utc=dt_utc.isoformat(),
        timestamp_npt=dt_npt.isoformat(),
        bs_date_iso=bs_iso,
        bs_date_devanagari=bs_deva,
        bs_combined_label=combined,
        ad_date_iso=ad_iso,
        bs_ad_official_label=bs_ad_official,
    )


def bs_to_ad_date(bs_year: int, bs_month: int, bs_day: int) -> date:
    """Convert a Bikram Sambat (BS) date into a Gregorian (AD) date."""
    bs_d = nepali_datetime.date(bs_year, bs_month, bs_day)
    ad_val: date = bs_d.to_datetime_date()
    return ad_val


def format_bs_now_label() -> str:
    """Return current Bikram Sambat combined label (e.g., '2083-07-09 BS | २०८३ कार्तिक ९')."""
    return ad_to_bs_stamp().bs_combined_label
