import json
import logging
import re
from pathlib import Path
from threading import Lock
from typing import Any, Dict, Optional, Tuple

import pubchempy as pcp

try:
    from rdkit import Chem
    from rdkit.Chem import Descriptors, rdMolDescriptors
except ImportError as exc:  # pragma: no cover
    Chem = None
    Descriptors = None
    rdMolDescriptors = None
    _rdkit_error = exc
else:
    _rdkit_error = None

logging.basicConfig(level=logging.INFO)
LOGGER = logging.getLogger(__name__)
CACHE_PATH = Path(__file__).resolve().with_name("resolver_cache.json")
_CACHE_LOCK = Lock()
_CACHE: Optional[Dict[str, Any]] = None


def _normalize_key(name: str) -> str:
    return name.strip().lower()


def _load_cache() -> Dict[str, Any]:
    global _CACHE
    if _CACHE is not None:
        return _CACHE
    if CACHE_PATH.exists():
        try:
            _CACHE = json.loads(CACHE_PATH.read_text(encoding="utf-8"))
        except Exception as exc:
            LOGGER.warning("Cache load failed: %s", exc)
            _CACHE = {}
    else:
        _CACHE = {}
    return _CACHE


def _get_cached(name: str) -> Optional[Dict[str, Any]]:
    key = _normalize_key(name)
    with _CACHE_LOCK:
        cache = _load_cache()
        cached = cache.get(key)
        if isinstance(cached, dict):
            return cached
    return None


def _set_cached(name: str, payload: Dict[str, Any]) -> None:
    key = _normalize_key(name)
    with _CACHE_LOCK:
        cache = _load_cache()
        cache[key] = payload
        try:
            CACHE_PATH.write_text(
                json.dumps(cache, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
        except Exception as exc:
            LOGGER.warning("Cache write failed: %s", exc)


def _clean_name(name: Optional[str]) -> str:
    if not name:
        return ""
    cleaned = name.strip().strip('"').strip("'").strip("`")
    cleaned = re.sub(
        r"^(IUPAC|IUPAC name|Name|English name|英文名|标准名称|标准名)[:：]\s*",
        "",
        cleaned,
        flags=re.IGNORECASE,
    )
    cleaned = cleaned.strip().strip("。：;，,")
    return cleaned


def _looks_chinese(text: str) -> bool:
    return bool(re.search(r"[\u4e00-\u9fff]", text))


def _pubchem_smiles(names: list[str]) -> tuple[Optional[str], Optional[str]]:
    for raw in names:
        name = _clean_name(raw)
        if not name:
            continue
        try:
            compounds = pcp.get_compounds(name, "name")
        except Exception as exc:
            LOGGER.warning("PubChem lookup failed (%s): %s", name, exc)
            continue
        if not compounds:
            continue
        compound = compounds[0]
        smiles = compound.canonical_smiles or compound.isomeric_smiles
        if smiles:
            return smiles, name
    return None, None


def _opsin_smiles(iupac_name: str) -> Optional[str]:
    cleaned = _clean_name(iupac_name)
    if not cleaned or _looks_chinese(cleaned):
        return None
    try:
        import pyopsin
    except Exception as exc:
        LOGGER.warning("OPSIN import failed: %s", exc)
        return None

    try:
        if hasattr(pyopsin, "name_to_smiles"):
            return pyopsin.name_to_smiles(cleaned)
        if hasattr(pyopsin, "opsin"):
            return pyopsin.opsin(cleaned)
        if hasattr(pyopsin, "OPSIN"):
            return pyopsin.OPSIN().name_to_smiles(cleaned)
    except Exception as exc:
        LOGGER.warning("OPSIN parse failed: %s", exc)
        return None
    return None


def _canonicalize(smiles: Optional[str]) -> Optional[str]:
    if not smiles:
        return None
    if Chem is None:
        raise RuntimeError("RDKit is required for canonicalization")
    mol = Chem.MolFromSmiles(smiles)
    if mol is None:
        return None
    return Chem.MolToSmiles(mol, canonical=True)


def _calc_props(smiles: str) -> Tuple[Optional[float], Optional[str]]:
    if Chem is None:
        raise RuntimeError("RDKit is required for molecular properties")
    mol = Chem.MolFromSmiles(smiles)
    if mol is None:
        return None, None
    weight = float(Descriptors.MolWt(mol)) if Descriptors else None
    formula = (
        rdMolDescriptors.CalcMolFormula(mol)
        if rdMolDescriptors is not None
        else None
    )
    return weight, formula


def resolve_smiles_from_name(
    iupac_name: str,
    original_name: Optional[str] = None,
) -> Dict[str, Any]:
    primary_key = _clean_name(iupac_name) or _clean_name(original_name)
    cached = _get_cached(primary_key)
    if cached is not None:
        return {
            "status": "ok",
            "source": "cache",
            "iupac_name": primary_key or iupac_name,
            **cached,
        }

    if _rdkit_error is not None:
        return {
            "status": "error",
            "error": f"RDKit unavailable: {_rdkit_error}",
        }

    candidates: list[str] = []
    if iupac_name:
        candidates.append(iupac_name)
    if original_name and original_name not in candidates:
        candidates.append(original_name)

    pubchem_smiles, pubchem_query = _pubchem_smiles(candidates)
    opsin_smiles = _opsin_smiles(iupac_name)

    canonical_pubchem = _canonicalize(pubchem_smiles)
    canonical_opsin = _canonicalize(opsin_smiles)

    chosen = None
    source = None
    mismatch = None

    if canonical_pubchem and canonical_opsin:
        if canonical_pubchem == canonical_opsin:
            chosen = canonical_pubchem
            source = "both"
        else:
            chosen = canonical_pubchem
            source = "pubchem"
            mismatch = {
                "pubchem": canonical_pubchem,
                "opsin": canonical_opsin,
            }
            LOGGER.warning("SMILES mismatch: %s", mismatch)
    elif canonical_pubchem:
        chosen = canonical_pubchem
        source = "pubchem"
    elif canonical_opsin:
        chosen = canonical_opsin
        source = "opsin"

    if not chosen:
        return {
            "status": "error",
            "error": "No valid SMILES from PubChem or OPSIN",
            "pubchem_smiles": pubchem_smiles,
            "opsin_smiles": opsin_smiles,
        }

    weight, formula = _calc_props(chosen)

    resolved_name = _clean_name(iupac_name) or _clean_name(original_name)
    result = {
        "status": "ok",
        "iupac_name": resolved_name,
        "canonical_smiles": chosen,
        "source": source,
        "molecular_weight": weight,
        "molecular_formula": formula,
        "pubchem_smiles": pubchem_smiles,
        "pubchem_query": pubchem_query,
        "opsin_smiles": opsin_smiles,
        "mismatch": mismatch,
    }
    _set_cached(resolved_name or iupac_name, {
        "canonical_smiles": chosen,
        "source": source,
        "molecular_weight": weight,
        "molecular_formula": formula,
        "pubchem_smiles": pubchem_smiles,
        "pubchem_query": pubchem_query,
        "opsin_smiles": opsin_smiles,
        "mismatch": mismatch,
    })
    return result
