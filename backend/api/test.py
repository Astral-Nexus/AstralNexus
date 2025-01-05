# test_api.py
import requests

BASE_URL = "http://localhost:8000"

def test_api():
    # Test root endpoint
    response = requests.get(f"{BASE_URL}/")
    print("Root endpoint:", response.json())

    # Test character creation
    character_data = {
        "player_address": "0x84c2f35807fC555C4A06cC12Dc0aAf9d948FeE1d",
        "character_class": "Warrior",
        "attribute_names": ["strength", "dexterity"],
        "attribute_values": [10, 8]
    }
    response = requests.post(f"{BASE_URL}/character/create", json=character_data)
    print("Create character:", response.json())

    # Test token balance
    response = requests.get(f"{BASE_URL}/token/balance/0x84c2f35807fC555C4A06cC12Dc0aAf9d948FeE1d")
    print("Token balance:", response.json())

if __name__ == "__main__":
    test_api()