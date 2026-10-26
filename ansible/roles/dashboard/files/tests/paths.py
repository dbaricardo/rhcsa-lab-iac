"""Caminhos do repositório rhcsa-lab-iac para os testes do dashboard.

No homelab tudo ficava num diretório só; aqui os arquivos estão espalhados
pelos roles. Importar este módulo também põe backend.py (dashboard) e
ai_review.py (role ai_review) no sys.path.
"""
import sys
from pathlib import Path

FILES = Path(__file__).resolve().parent.parent          # roles/dashboard/files
ROLES = FILES.parent.parent                              # ansible/roles
REPO = ROLES.parent.parent                               # raiz do repositório
CATALOG = REPO / 'labs' / 'catalog.json'
AI_REVIEW_DIR = ROLES / 'ai_review' / 'files'
WORKSTATION_FILES = ROLES / 'workstation' / 'files'
LAB_FULL = WORKSTATION_FILES / 'lab-full'
HOSTS = REPO / 'labs' / 'hosts'
REVIEWER = REPO / 'contrib' / 'ai-reviewer' / 'rhcsa-ai-review'
REVIEWER_OPENAI = REPO / 'contrib' / 'ai-reviewer' / 'rhcsa-ai-review-openai'

for _path in (FILES, AI_REVIEW_DIR):
    if str(_path) not in sys.path:
        sys.path.insert(0, str(_path))
