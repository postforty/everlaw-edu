import os
import redis
from dotenv import load_dotenv
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_ollama import OllamaEmbeddings

# Load environmental variables
load_dotenv()

GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")
OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL")
POSTGRES_URL = os.getenv("POSTGRES_URL")
LLM_MODEL = os.getenv("LLM_MODEL")
EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL")
REDIS_URL = os.getenv("REDIS_URL")

# MOEL RSS & GitHub config
MOEL_RSS_URL = os.getenv("MOEL_RSS_URL")
LAW_API_ENDPOINT = os.getenv("LAW_API_ENDPOINT")
GITHUB_REPO = os.getenv("GITHUB_REPO", "legalize-kr/legalize-kr")
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")

# Initialize Redis
if REDIS_URL:
    r = redis.from_url(REDIS_URL)
else:
    r = None
    print("⚠️ REDIS_URL이 설정되지 않았습니다. 캐싱이 비활성화됩니다.")

# Initialize Embedding Model
embeddings = OllamaEmbeddings(
    base_url=OLLAMA_BASE_URL,
    model=EMBEDDING_MODEL
)

# Initialize Chat LLM
llm = ChatGoogleGenerativeAI(
    model=LLM_MODEL,
    google_api_key=GOOGLE_API_KEY,
    temperature=0
)

# Vector DB configuration
CONNECTION_STRING = POSTGRES_URL
COLLECTION_NAME = "law_documents"
COLLECTION_NAME_CURRICULUM = "curriculum_documents"
EMBEDDING_BATCH_SIZE = int(os.getenv("EMBEDDING_BATCH_SIZE", "50"))

