using Terraria.ID;

namespace ChainsawManMod.Content.Projectiles
{
	// Fireball used by the Fire Devil. Sets the player on fire.
	public class FireBolt : DevilShotBase
	{
		protected override int DustType => DustID.Torch;
		protected override int DebuffType => BuffID.OnFire;
	}
}
