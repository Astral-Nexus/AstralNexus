from fastapi import FastAPI, HTTPException
from web3 import Web3
from dotenv import load_dotenv
import os
import json
from typing import List
from pydantic import BaseModel
from config import settings

app = FastAPI(title="Astral Nexus Game API")

# Load environment variables
load_dotenv()

# Function to load contract ABI
def load_contract_abi(contract_name: str):
    file_path = settings.CONTRACTS_DIR / f"{contract_name}.json"
    try:
        with open(file_path) as f:
            return json.load(f)['abi']
    except FileNotFoundError:
        raise Exception(f"Contract ABI file not found: {file_path}")

# Connect to EduChain testnet
w3 = Web3(Web3.HTTPProvider(settings.RPC_URL))

# Initialize contracts
try:
    contracts = {
        'items': w3.eth.contract(
            address=settings.ITEMS_CONTRACT_ADDRESS,
            abi=load_contract_abi("AstralNexusItems")
        ),
        'character': w3.eth.contract(
            address=settings.CHARACTER_CONTRACT_ADDRESS,
            abi=load_contract_abi("AstralNexusCharacter")
        ),
        'token': w3.eth.contract(
            address=settings.TOKEN_CONTRACT_ADDRESS,
            abi=load_contract_abi("AstralNexusToken")
        ),
        'exchange': w3.eth.contract(
            address=settings.EXCHANGE_CONTRACT_ADDRESS,
            abi=load_contract_abi("AstralNexusExchange")
        )
    }
except Exception as e:
    print(f"Error loading contracts: {str(e)}")
    raise

# Pydantic models
class CharacterCreate(BaseModel):
    player_address: str
    character_class: str
    attribute_names: List[str]
    attribute_values: List[int]

class ItemCreate(BaseModel):
    player_address: str
    name: str
    item_type: int
    rarity: int
    level: int
    stats: List[int]
    property_names: List[str]
    property_values: List[str]
    tradeable: bool
    soulbound: bool

# Helper function for transactions
async def send_transaction(transaction, private_key):
    try:
        signed_txn = w3.eth.account.sign_transaction(transaction, private_key)
        tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)
        return await w3.eth.wait_for_transaction_receipt(tx_hash)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Transaction failed: {str(e)}")

# API Routes
@app.get("/")
async def read_root():
    return {
        "message": "Welcome to Astral Nexus Game API",
        "contracts": {
            "token": settings.TOKEN_CONTRACT_ADDRESS,
            "items": settings.ITEMS_CONTRACT_ADDRESS,
            "character": settings.CHARACTER_CONTRACT_ADDRESS,
            "exchange": settings.EXCHANGE_CONTRACT_ADDRESS
        }
    }

@app.post("/character/create")
async def create_character(character: CharacterCreate):
    try:
        private_key = os.getenv("ADMIN_PRIVATE_KEY")
        account = w3.eth.account.from_key(private_key)
        nonce = w3.eth.get_transaction_count(account.address)
        
        transaction = contracts['character'].functions.createCharacter(
            character.player_address,
            character.character_class,
            character.attribute_names,
            character.attribute_values
        ).build_transaction({
            'gas': 2000000,
            'gasPrice': w3.eth.gas_price,
            'nonce': nonce,
        })
        
        receipt = await send_transaction(transaction, private_key)
        return {
            "success": True,
            "transaction_hash": receipt['transactionHash'].hex(),
            "block_number": receipt['blockNumber']
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/character/{character_id}")
async def get_character(character_id: int):
    try:
        character = await contracts['character'].functions.getCharacter(character_id).call()
        return {
            "class": character[0],
            "level": character[1],
            "exp": character[2],
            "equippedItems": character[3],
            "lastLogin": character[4]
        }
    except Exception as e:
        raise HTTPException(status_code=404, detail=str(e))

@app.get("/token/balance/{address}")
async def get_token_balance(address: str):
    try:
        balance = await contracts['token'].functions.balanceOf(address).call()
        return {"balance": balance}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/exchange/rates")
async def get_exchange_rates():
    try:
        game_to_edu = await contracts['exchange'].functions.rateGameToEdu().call()
        edu_to_game = await contracts['exchange'].functions.rateEduToGame().call()
        return {
            "gameToEdu": game_to_edu,
            "eduToGame": edu_to_game
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))