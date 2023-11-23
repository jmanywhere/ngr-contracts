import json

with open("positions_data.json", "r") as all_positions:
    positions = json.load(all_positions)
    position_list = positions["0"]
    ids_to_liquidate = []
    for index,position in enumerate(position_list):
        if position["isLiquidated"] == False:
            ids_to_liquidate.append(index)
    print(ids_to_liquidate)