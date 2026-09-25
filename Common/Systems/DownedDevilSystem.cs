using System.Collections.Generic;
using System.IO;
using System.Linq;
using Terraria;
using Terraria.ModLoader;
using Terraria.ModLoader.IO;

namespace ChainsawManMod.Common.Systems
{
	// Remembers which devil bosses have been defeated in this world (same approach as ExampleMod's DownedBossSystem).
	public class DownedDevilSystem : ModSystem
	{
		public static bool downedZombieDevil = false;
		public static bool downedBatDevil = false;
		public static bool downedEternityDevil = false;
		public static bool downedGunDevil = false;
		public static bool downedMakima = false;
		public static bool downedTyphoonDevil = false;
		public static bool downedDarknessDevil = false;

		// Bosses added later (DevilBossBase) are tracked by name instead of one field each.
		public static readonly HashSet<string> downedBosses = new();

		public static bool IsDowned(string key) => downedBosses.Contains(key);

		// Call from a boss's OnKill. The game syncs world data to clients after a boss dies.
		public static void MarkDowned(string key) {
			downedBosses.Add(key);
		}

		public override void ClearWorld() {
			downedZombieDevil = false;
			downedBatDevil = false;
			downedEternityDevil = false;
			downedGunDevil = false;
			downedMakima = false;
			downedTyphoonDevil = false;
			downedDarknessDevil = false;
			downedBosses.Clear();
		}

		public override void SaveWorldData(TagCompound tag) {
			if (downedZombieDevil) {
				tag["downedZombieDevil"] = true;
			}
			if (downedBatDevil) {
				tag["downedBatDevil"] = true;
			}
			if (downedEternityDevil) {
				tag["downedEternityDevil"] = true;
			}
			if (downedGunDevil) {
				tag["downedGunDevil"] = true;
			}
			if (downedMakima) {
				tag["downedMakima"] = true;
			}
			if (downedTyphoonDevil) {
				tag["downedTyphoonDevil"] = true;
			}
			if (downedDarknessDevil) {
				tag["downedDarknessDevil"] = true;
			}
			if (downedBosses.Count > 0) {
				tag["downedBosses"] = downedBosses.ToList();
			}
		}

		public override void LoadWorldData(TagCompound tag) {
			downedZombieDevil = tag.ContainsKey("downedZombieDevil");
			downedBatDevil = tag.ContainsKey("downedBatDevil");
			downedEternityDevil = tag.ContainsKey("downedEternityDevil");
			downedGunDevil = tag.ContainsKey("downedGunDevil");
			downedMakima = tag.ContainsKey("downedMakima");
			downedTyphoonDevil = tag.ContainsKey("downedTyphoonDevil");
			downedDarknessDevil = tag.ContainsKey("downedDarknessDevil");
			downedBosses.Clear();
			if (tag.ContainsKey("downedBosses")) {
				foreach (string key in tag.GetList<string>("downedBosses")) {
					downedBosses.Add(key);
				}
			}
		}

		public override void NetSend(BinaryWriter writer) {
			writer.WriteFlags(downedZombieDevil, downedBatDevil, downedEternityDevil, downedGunDevil, downedMakima, downedTyphoonDevil, downedDarknessDevil);
			writer.Write(downedBosses.Count);
			foreach (string key in downedBosses) {
				writer.Write(key);
			}
		}

		public override void NetReceive(BinaryReader reader) {
			reader.ReadFlags(out downedZombieDevil, out downedBatDevil, out downedEternityDevil, out downedGunDevil, out downedMakima, out downedTyphoonDevil, out downedDarknessDevil);
			downedBosses.Clear();
			int count = reader.ReadInt32();
			for (int i = 0; i < count; i++) {
				downedBosses.Add(reader.ReadString());
			}
		}
	}
}
