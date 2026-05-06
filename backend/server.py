from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from molecule_resolver import resolve_smiles_from_name

app = FastAPI(title="ChemVISION Resolver")


class ResolveRequest(BaseModel):
    iupac_name: str


@app.post("/resolve_smiles")
def resolve_smiles(request: ResolveRequest):
    result = resolve_smiles_from_name(request.iupac_name)
    if result.get("status") != "ok":
        raise HTTPException(status_code=400, detail=result.get("error"))
    return result
