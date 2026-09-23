using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Buffs
{
	// Prevents pulling the Starter Cord again right away.
	public class StarterCordCooldown : ModBuff
	{
		public override void SetStaticDefaults() {
			Main.debuff[Type] = true;
			BuffID.Sets.NurseCannotRemoveDebuff[Type] = true;
		}
	}
}
