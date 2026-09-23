using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Buffs
{
	// Applied after Pochita's Heart saves the player from death.
	public class PochitasContractCooldown : ModBuff
	{
		public override void SetStaticDefaults() {
			Main.debuff[Type] = true;
			Main.persistentBuff[Type] = true;
			BuffID.Sets.NurseCannotRemoveDebuff[Type] = true;
		}
	}
}
