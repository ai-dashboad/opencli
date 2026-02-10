"""Episode script data models.

Ported from daemon/lib/episode/episode_script.dart.
"""

from dataclasses import dataclass, field
from typing import Any


@dataclass
class DialogueLine:
    character_id: str
    text: str
    emotion: str = "neutral"
    voice: str = ""

    @classmethod
    def from_json(cls, data: dict) -> "DialogueLine":
        return cls(
            character_id=data.get("character_id", data.get("characterId", "")),
            text=data.get("text", ""),
            emotion=data.get("emotion", "neutral"),
            voice=data.get("voice", ""),
        )

    def to_json(self) -> dict:
        return {"character_id": self.character_id, "text": self.text,
                "emotion": self.emotion, "voice": self.voice}


@dataclass
class EpisodeScene:
    id: str
    description: str = ""
    visual_prompt: str = ""
    dialogue: list[DialogueLine] = field(default_factory=list)
    duration_seconds: float = 10.0
    shot_type: str = "medium"
    transition: str = "fade"

    @classmethod
    def from_json(cls, data: dict) -> "EpisodeScene":
        return cls(
            id=data.get("id", ""),
            description=data.get("description", ""),
            visual_prompt=data.get("visual_prompt", data.get("visualPrompt", "")),
            dialogue=[DialogueLine.from_json(d) for d in data.get("dialogue", [])],
            duration_seconds=float(data.get("duration_seconds", data.get("durationSeconds", 10))),
            shot_type=data.get("shot_type", data.get("shotType", "medium")),
            transition=data.get("transition", "fade"),
        )

    def to_json(self) -> dict:
        return {
            "id": self.id, "description": self.description,
            "visual_prompt": self.visual_prompt,
            "dialogue": [d.to_json() for d in self.dialogue],
            "duration_seconds": self.duration_seconds,
            "shot_type": self.shot_type, "transition": self.transition,
        }


@dataclass
class CharacterDefinition:
    id: str
    name: str
    visual_description: str = ""
    default_voice: str = "zh-CN-XiaoxiaoNeural"
    reference_image_path: str = ""

    @classmethod
    def from_json(cls, data: dict) -> "CharacterDefinition":
        return cls(
            id=data.get("id", ""),
            name=data.get("name", ""),
            visual_description=data.get("visual_description", data.get("visualDescription", "")),
            default_voice=data.get("default_voice", data.get("defaultVoice", "zh-CN-XiaoxiaoNeural")),
            reference_image_path=data.get("reference_image_path", ""),
        )

    def to_json(self) -> dict:
        return {"id": self.id, "name": self.name,
                "visual_description": self.visual_description,
                "default_voice": self.default_voice,
                "reference_image_path": self.reference_image_path}


@dataclass
class EpisodeScript:
    title: str = ""
    synopsis: str = ""
    characters: list[CharacterDefinition] = field(default_factory=list)
    scenes: list[EpisodeScene] = field(default_factory=list)

    @classmethod
    def from_json(cls, data: dict) -> "EpisodeScript":
        return cls(
            title=data.get("title", ""),
            synopsis=data.get("synopsis", ""),
            characters=[CharacterDefinition.from_json(c) for c in data.get("characters", [])],
            scenes=[EpisodeScene.from_json(s) for s in data.get("scenes", [])],
        )

    def to_json(self) -> dict:
        return {
            "title": self.title, "synopsis": self.synopsis,
            "characters": [c.to_json() for c in self.characters],
            "scenes": [s.to_json() for s in self.scenes],
        }
