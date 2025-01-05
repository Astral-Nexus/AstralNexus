from pathlib import Path
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    BASE_DIR: Path = Path(__file__).resolve().parent.parent
    CONTRACTS_DIR: Path = BASE_DIR / "src" / "contracts" / "AstraNexus.sol"
    RPC_URL: str = "https://rpc.open-campus-codex.gelato.digital"
    
    # Contract addresses
    ITEMS_CONTRACT_ADDRESS: str = "0xd9BfD73FE6B7481fF056Bf31239c2c4F019c0542"
    CHARACTER_CONTRACT_ADDRESS: str = "0x3E2F5568494fF67de705fA6BAaB2D8262AB3c7EE"
    TOKEN_CONTRACT_ADDRESS: str = "0xA2C7CaEf4aA9a3da0eaEd89C70Efff1b8818A156"
    EXCHANGE_CONTRACT_ADDRESS: str = "0xA6B0321Cc05672FF44F4E907A54465c0DEf74E77"
    
    class Config:
        env_file = ".env"

settings = Settings()