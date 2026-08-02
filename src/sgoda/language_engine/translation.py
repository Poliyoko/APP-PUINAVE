"""Traducción local con Argos Translate."""

from __future__ import annotations

from .models import TranslationResult


class LocalTranslationUnavailable(RuntimeError):
    pass


class ArgosLocalTranslator:
    provider_id = "argos-translate"

    @staticmethod
    def available_pairs() -> list[tuple[str, str]]:
        try:
            from argostranslate import translate
        except ImportError:
            return []

        installed = translate.get_installed_languages()
        pairs: list[tuple[str, str]] = []

        for source in installed:
            for target in installed:
                if source.code == target.code:
                    continue
                try:
                    source.get_translation(target)
                except Exception:
                    continue
                pairs.append((source.code, target.code))

        return sorted(set(pairs))

    def translate(
        self,
        text: str,
        source_code: str,
        target_code: str,
        target_locale: str,
    ) -> TranslationResult:
        try:
            from argostranslate import translate
        except ImportError as exc:
            raise LocalTranslationUnavailable(
                "Argos Translate no está instalado."
            ) from exc

        source = next(
            (
                item
                for item in translate.get_installed_languages()
                if item.code == source_code
            ),
            None,
        )
        target = next(
            (
                item
                for item in translate.get_installed_languages()
                if item.code == target_code
            ),
            None,
        )

        if source is None or target is None:
            raise LocalTranslationUnavailable(
                f"No existe el par {source_code}->{target_code}."
            )

        translated = source.get_translation(target).translate(text)

        return TranslationResult(
            source_text=text,
            translated_text=translated,
            source_locale="es-CO",
            target_locale=target_locale,
            provider=self.provider_id,
            status="machine_proposed_pending_review",
        )