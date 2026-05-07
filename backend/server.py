from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from molecule_resolver import resolve_smiles_from_name

app = FastAPI(title="ChemVISION Resolver")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class ResolveRequest(BaseModel):
    iupac_name: str
    original_name: str | None = None


@app.post("/resolve_smiles")
def resolve_smiles(request: ResolveRequest):
    result = resolve_smiles_from_name(
        request.iupac_name,
        original_name=request.original_name,
    )
    if result.get("status") != "ok":
        raise HTTPException(status_code=400, detail=result.get("error"))
    return result
