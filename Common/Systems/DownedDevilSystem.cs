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

		public override void ClearWorld() {
			downedZombieDevil = false;
			downedBatDevil = false;
		}

		public override void SaveWorldData(TagCompound tag) {
			if (downedZombieDevil) {
				tag["downedZombieDevil"] = true;
			}
			if (downedBatDevil) {
				tag["downedBatDevil"] = true;
			}
		}

		public override void LoadWorldData(TagCompound tag) {
			downedZombieDevil = tag.ContainsKey("downedZombieDevil");
			downedBatDevil = tag.ContainsKey("downedBatDevil");
		}

		public override void NetSend(BinaryWriter writer) {
			writer.WriteFlags(downedZombieDevil, downedBatDevil);
		}

		public override void NetReceive(BinaryReader reader) {
			reader.ReadFlags(out downedZombieDevil, out downedBatDevil);
		}
	}
}
