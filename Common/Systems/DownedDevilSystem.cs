using System.IO;
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

		public override void ClearWorld() {
			downedZombieDevil = false;
			downedBatDevil = false;
			downedEternityDevil = false;
			downedGunDevil = false;
			downedMakima = false;
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
		}

		public override void LoadWorldData(TagCompound tag) {
			downedZombieDevil = tag.ContainsKey("downedZombieDevil");
			downedBatDevil = tag.ContainsKey("downedBatDevil");
			downedEternityDevil = tag.ContainsKey("downedEternityDevil");
			downedGunDevil = tag.ContainsKey("downedGunDevil");
			downedMakima = tag.ContainsKey("downedMakima");
		}

		public override void NetSend(BinaryWriter writer) {
			writer.WriteFlags(downedZombieDevil, downedBatDevil, downedEternityDevil, downedGunDevil, downedMakima);
		}

		public override void NetReceive(BinaryReader reader) {
			reader.ReadFlags(out downedZombieDevil, out downedBatDevil, out downedEternityDevil, out downedGunDevil, out downedMakima);
		}
	}
}
