using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace RobotJack.Content.Buffs
{
	// The satellite is recharging after an Orbital Cannon Strike.
	public class OrbitalCannonCooldown : ModBuff
	{
		public override void SetStaticDefaults() {
			Main.debuff[Type] = true;
			Main.buffNoSave[Type] = true;
			BuffID.Sets.NurseCannotRemoveDebuff[Type] = true;
		}
	}
}
