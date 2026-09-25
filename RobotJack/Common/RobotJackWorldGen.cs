using RobotJack.Content.Items;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace RobotJack.Common
{
	// Hides Robot Triggers in underground Gold Chests when a new world is generated.
	public class RobotJackWorldGen : ModSystem
	{
		// Roughly one in this many underground Gold Chests gets a Robot Trigger (at least one per world).
		private const int ChestChance = 4;

		// Frame column of the Gold Chest in the vanilla Containers tile sheet (each chest style is 36 px wide).
		private const int GoldChestStyle = 1;

		public override void PostWorldGen() {
			int triggerType = ModContent.ItemType<RobotTrigger>();
			int placed = 0;
			int firstCandidate = -1;

			for (int chestIndex = 0; chestIndex < Main.maxChests; chestIndex++) {
				Chest chest = Main.chest[chestIndex];
				if (chest == null || !IsUndergroundGoldChest(chest)) {
					continue;
				}
				if (firstCandidate < 0 && FirstEmptySlot(chest) >= 0) {
					firstCandidate = chestIndex;
				}
				if (WorldGen.genRand.NextBool(ChestChance) && TryAdd(chest, triggerType)) {
					placed++;
				}
			}

			// Make sure every world has at least one.
			if (placed == 0 && firstCandidate >= 0) {
				TryAdd(Main.chest[firstCandidate], triggerType);
			}
		}

		private static bool IsUndergroundGoldChest(Chest chest) {
			Tile tile = Main.tile[chest.x, chest.y];
			return tile.TileType == TileID.Containers
				&& tile.TileFrameX / 36 == GoldChestStyle
				&& chest.y > Main.worldSurface;
		}

		private static int FirstEmptySlot(Chest chest) {
			for (int i = 0; i < Chest.maxItems; i++) {
				if (chest.item[i].IsAir) {
					return i;
				}
			}
			return -1;
		}

		private static bool TryAdd(Chest chest, int type) {
			int slot = FirstEmptySlot(chest);
			if (slot < 0) {
				return false;
			}
			chest.item[slot].SetDefaults(type);
			return true;
		}
	}
}
