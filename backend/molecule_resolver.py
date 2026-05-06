import logging
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


def _pubchem_smiles(iupac_name: str) -> Optional[str]:
    try:
        compounds = pcp.get_compounds(iupac_name, "name")
    except Exception as exc:
        LOGGER.warning("PubChem lookup failed: %s", exc)
        return None
    if not compounds:
        return None
    compound = compounds[0]
    return compound.canonical_smiles or compound.isomeric_smiles


def _opsin_smiles(iupac_name: str) -> Optional[str]:
    try:
        import pyopsin
    except Exception as exc:
        LOGGER.warning("OPSIN import failed: %s", exc)
        return None

    try:
        if hasattr(pyopsin, "name_to_smiles"):
            return pyopsin.name_to_smiles(iupac_name)
        if hasattr(pyopsin, "opsin"):
            return pyopsin.opsin(iupac_name)
        if hasattr(pyopsin, "OPSIN"):
            return pyopsin.OPSIN().name_to_smiles(iupac_name)
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


def resolve_smiles_from_name(iupac_name: str) -> Dict[str, Any]:
    if _rdkit_error is not None:
        return {
            "status": "error",
            "error": f"RDKit unavailable: {_rdkit_error}",
        }

    pubchem_smiles = _pubchem_smiles(iupac_name)
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

    return {
        "status": "ok",
        "iupac_name": iupac_name,
        "canonical_smiles": chosen,
        "source": source,
        "molecular_weight": weight,
        "molecular_formula": formula,
        "pubchem_smiles": pubchem_smiles,
        "opsin_smiles": opsin_smiles,
        "mismatch": mismatch,
    }
