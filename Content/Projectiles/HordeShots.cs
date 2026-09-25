using Terraria.ID;

namespace ChainsawManMod.Content.Projectiles
{
	// Hostile shots for the second wave of devils. All share DevilShotBase (ai[0] == 1 adds gravity).

	public class IceShard : DevilShotBase
	{
		protected override int DustType => DustID.IceTorch;
		protected override int DebuffType => BuffID.Frostburn;
		protected override bool Spins => false;
		protected override int Size => 10;
	}

	public class VenomBolt : DevilShotBase
	{
		protected override int DustType => DustID.JungleGrass;
		protected override int DebuffType => BuffID.Venom;
	}

	public class SandBolt : DevilShotBase
	{
		protected override int DustType => DustID.Sand;
		protected override int Size => 16;
	}

	public class InkBolt : DevilShotBase
	{
		protected override int DustType => DustID.Smoke;
		protected override int DebuffType => BuffID.Darkness;
	}

	public class LightningBolt : DevilShotBase
	{
		protected override int DustType => DustID.Electric;
		protected override int DebuffType => BuffID.Electrified;
		protected override bool Spins => false;
		protected override int Size => 10;
	}

	public class NeedleShot : DevilShotBase
	{
		protected override int DustType => DustID.Silver;
		protected override bool Spins => false;
		protected override int Size => 8;
	}

	public class ShardBolt : DevilShotBase
	{
		protected override int DustType => DustID.WhiteTorch;
		protected override int DebuffType => BuffID.Confused;
		protected override int Size => 12;
	}

	public class FutureBolt : DevilShotBase
	{
		protected override int DustType => DustID.Electric;
		protected override int DebuffType => BuffID.Confused;
		protected override bool Spins => false;
		protected override int Size => 12;
	}

	public class WeaponShard : DevilShotBase
	{
		protected override int DustType => DustID.Silver;
		protected override int Size => 16;
	}

	public class FamineBolt : DevilShotBase
	{
		protected override int DustType => DustID.Smoke;
		protected override int DebuffType => BuffID.Slow;
	}

	public class FallingStar : DevilShotBase
	{
		protected override int DustType => DustID.Torch;
		protected override int DebuffType => BuffID.OnFire;
		protected override int Size => 18;
	}

	public class DeathBolt : DevilShotBase
	{
		protected override int DustType => DustID.Smoke;
		protected override int DebuffType => BuffID.Cursed;
		protected override int Size => 16;
	}
}
